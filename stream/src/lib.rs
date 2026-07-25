mod pb {
    include!(concat!(env!("OUT_DIR"), "/pista.aggregate.v1.rs"));
}

use std::collections::{HashMap, HashSet};

use pb::FraudData;
use substreams::errors::Error;
use substreams::pb::substreams::store_delta::Operation as DeltaOperation;
use substreams::scalar::BigInt;
use substreams::store::{DeltaInt64, Deltas, StoreNew, StoreSet, StoreSetInt64};
use substreams::Hex;
use substreams_ethereum::pb::eth::v2 as eth;
use substreams_ethereum::pb::eth::v2::transaction_trace::Type as TrxType;
use substreams_ethereum::pb::eth::v2::TransactionTraceStatus as TrxStatus;

// "Dust": non-zero transfers too small to be a deliberate payment, e.g. spam/probing.
const DUST_THRESHOLD_WEI: u64 = 100_000_000_000_000; // 0.0001 ETH

// keccak256("Transfer(address,address,uint256)")
const TRANSFER_TOPIC0: [u8; 32] = [
    0xdd, 0xf2, 0x52, 0xad, 0x1b, 0xe2, 0xc8, 0x9b, 0x69, 0xc2, 0xb0, 0x68, 0xfc, 0x37, 0x8d, 0xaa,
    0x95, 0x2b, 0xa7, 0xf1, 0x63, 0xc4, 0xa1, 0x16, 0x28, 0xf5, 0x5a, 0x4d, 0xf5, 0x23, 0xb3, 0xef,
];

// Sepolia testnet stablecoins, 1 token assumed == 1 USD. Extend as more are confirmed.
const STABLECOINS: &[(&str, u64)] = &[
    ("0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", 6),  // USDC (Circle, official)
    ("0x3ac67bde59f4cf4ed9dab695fe61959d1c2b3b09", 18), // DAI (faucet token)
];

fn hex0x(bytes: &[u8]) -> String {
    format!("0x{}", Hex::encode(bytes))
}

#[substreams::handlers::store]
fn store_block_interval(block: eth::Block, store: StoreSetInt64) {
    let timestamp = block
        .header
        .as_ref()
        .and_then(|h| h.timestamp.as_ref())
        .map(|t| t.seconds)
        .unwrap_or_default();
    store.set(0, "timestamp", &timestamp);
}

fn block_interval_seconds(deltas: &Deltas<DeltaInt64>) -> i32 {
    deltas
        .deltas
        .iter()
        .find(|d| d.key == "timestamp")
        .map(|d| {
            if d.operation == DeltaOperation::Create {
                0
            } else {
                (d.new_value - d.old_value) as i32
            }
        })
        .unwrap_or(0)
}

fn effective_priority_fee_gwei(trx: &eth::TransactionTrace, base_fee_per_gas: &BigInt) -> Option<f64> {
    let gas_price: BigInt = trx.gas_price.as_ref()?.into();
    if &gas_price <= base_fee_per_gas {
        return Some(0.0);
    }
    let mut priority_wei = gas_price;
    priority_wei -= base_fee_per_gas.clone();
    Some(priority_wei.to_u64() as f64 / 1_000_000_000.0)
}

fn stablecoin_volume_usd(txs: &[&eth::TransactionTrace]) -> f64 {
    let mut total = 0.0f64;
    for trx in txs {
        let Some(receipt) = trx.receipt.as_ref() else {
            continue;
        };
        for log in &receipt.logs {
            if log.topics.first().map(|t| t.as_slice()) != Some(&TRANSFER_TOPIC0[..]) {
                continue;
            }
            let address = hex0x(&log.address);
            let Some((_, decimals)) = STABLECOINS.iter().find(|(addr, _)| *addr == address) else {
                continue;
            };
            let amount = BigInt::from_unsigned_bytes_be(&log.data).to_decimal(*decimals);
            total += amount.to_string().parse::<f64>().unwrap_or(0.0);
        }
    }
    total
}

#[substreams::handlers::map]
fn extract_fraud_relevant_data(
    block: eth::Block,
    interval_deltas: Deltas<DeltaInt64>,
) -> Result<FraudData, Error> {
    let block_timestamp = block
        .header
        .as_ref()
        .and_then(|h| h.timestamp.as_ref())
        .map(|t| t.seconds as u64)
        .unwrap_or_default();

    let gas_limit = block.header.as_ref().map(|h| h.gas_limit).unwrap_or_default();
    let gas_used = block.header.as_ref().map(|h| h.gas_used).unwrap_or_default();
    let gas_utilization = if gas_limit > 0 {
        gas_used as f64 / gas_limit as f64
    } else {
        0.0
    };
    let base_fee_per_gas = block
        .header
        .as_ref()
        .and_then(|h| h.base_fee_per_gas.as_ref())
        .map(Into::<BigInt>::into)
        .unwrap_or_else(BigInt::zero);

    let txs: Vec<&eth::TransactionTrace> = block.transaction_traces.iter().collect();
    let dust_threshold = BigInt::from(DUST_THRESHOLD_WEI);

    let mut senders = HashSet::new();
    let mut receivers = HashSet::new();
    let mut total_value = BigInt::zero();
    let mut zero_value_tx_count = 0u64;
    let mut dust_tx_count = 0u64;
    let mut failed_transactions = 0u64;
    let mut contract_creation_count = 0u64;
    let mut delegation_tx_count = 0u64;
    let mut priority_fees_gwei: Vec<f64> = Vec::new();

    let mut reverting_senders_by_contract: HashMap<Vec<u8>, HashSet<Vec<u8>>> = HashMap::new();
    let mut reverting_contract_order: Vec<Vec<u8>> = Vec::new();

    let mut creation_input_counts: HashMap<Vec<u8>, u64> = HashMap::new();
    let mut creation_inputs: Vec<Vec<u8>> = Vec::new();

    for trx in &txs {
        senders.insert(trx.from.clone());
        if !trx.to.is_empty() {
            receivers.insert(trx.to.clone());
        }

        let value = trx
            .value
            .as_ref()
            .map(Into::<BigInt>::into)
            .unwrap_or_else(BigInt::zero);
        if value == BigInt::zero() {
            zero_value_tx_count += 1;
        } else if value < dust_threshold {
            dust_tx_count += 1;
        }
        total_value += &value;

        if trx.status != TrxStatus::Succeeded as i32 {
            failed_transactions += 1;
            if !reverting_senders_by_contract.contains_key(&trx.to) {
                reverting_contract_order.push(trx.to.clone());
            }
            reverting_senders_by_contract
                .entry(trx.to.clone())
                .or_insert_with(HashSet::new)
                .insert(trx.from.clone());
        }

        if trx.to.is_empty() {
            contract_creation_count += 1;
            creation_inputs.push(trx.input.clone());
            *creation_input_counts.entry(trx.input.clone()).or_insert(0) += 1;
        }

        if trx.r#type == TrxType::TrxTypeSetCode as i32 {
            delegation_tx_count += 1;
        }

        if let Some(fee) = effective_priority_fee_gwei(trx, &base_fee_per_gas) {
            priority_fees_gwei.push(fee);
        }
    }

    let duplicate_bytecode_creation_count = creation_inputs
        .iter()
        .filter(|input| creation_input_counts.get(*input).copied().unwrap_or(0) > 1)
        .count() as u64;

    // First contract (in transaction order) with the most distinct reverted senders wins ties.
    let mut top_reverting: Option<(Vec<u8>, usize)> = None;
    for addr in &reverting_contract_order {
        let count = reverting_senders_by_contract
            .get(addr)
            .map(|s| s.len())
            .unwrap_or(0);
        if top_reverting.as_ref().map_or(true, |(_, best)| count > *best) {
            top_reverting = Some((addr.clone(), count));
        }
    }
    let (top_reverting_contract, top_reverting_distinct_senders) = top_reverting
        .map(|(addr, count)| (hex0x(&addr), count as u64))
        .unwrap_or_else(|| (String::new(), 0));

    priority_fees_gwei.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let priority_fee_max_gwei = priority_fees_gwei.last().copied().unwrap_or(0.0);
    let priority_fee_p50_gwei = if priority_fees_gwei.is_empty() {
        0.0
    } else {
        priority_fees_gwei[priority_fees_gwei.len() / 2]
    };

    Ok(FraudData {
        block_number: block.number,
        block_timestamp,
        block_interval_seconds: block_interval_seconds(&interval_deltas),
        gas_utilization,
        total_transactions: txs.len() as u64,
        unique_senders: senders.len() as u64,
        unique_receivers: receivers.len() as u64,
        total_value_wei: total_value.to_string(),
        zero_value_tx_count,
        dust_tx_count,
        stablecoin_volume_usd: stablecoin_volume_usd(&txs),
        failed_transactions,
        top_reverting_contract,
        top_reverting_distinct_senders,
        priority_fee_p50_gwei,
        priority_fee_max_gwei,
        contract_creation_count,
        duplicate_bytecode_creation_count,
        delegation_tx_count,
    })
}
