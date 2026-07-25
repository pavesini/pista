mod pb {
    include!(concat!(env!("OUT_DIR"), "/pista.transactions.v1.rs"));
}

use pb::{Transaction, Transactions};
use substreams::errors::Error;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::pb::eth::v2 as eth;

fn hex0x(bytes: &[u8]) -> String {
    format!("0x{}", Hex::encode(bytes))
}

#[substreams::handlers::map]
fn map_transactions_from(params: String, block: eth::Block) -> Result<Transactions, Error> {
    let trimmed = params.trim();
    if trimmed.is_empty() {
        return Err(Error::msg(
            "map_transactions_from requires a non-empty address param",
        ));
    }
    let target = Hex::decode(trimmed)
        .map_err(|e| Error::msg(format!("invalid address param '{trimmed}': {e}")))?;

    let mut transactions = Vec::new();
    for trx in block.transactions() {
        if trx.from == target {
            let value = trx
                .value
                .as_ref()
                .map(|v| Into::<BigInt>::into(v).to_string())
                .unwrap_or_else(|| "0".to_string());

            transactions.push(Transaction {
                block_number: block.number,
                block_timestamp: block
                    .header
                    .as_ref()
                    .and_then(|h| h.timestamp.as_ref())
                    .map(|t| t.seconds as u64)
                    .unwrap_or_default(),
                tx_hash: hex0x(&trx.hash),
                from: hex0x(&trx.from),
                to: hex0x(&trx.to),
                value,
                nonce: trx.nonce,
                index: trx.index,
            });
        }
    }

    Ok(Transactions { transactions })
}
