fn main() {
    prost_build::compile_protos(&["proto/aggregate.proto"], &["proto/"]).unwrap();
}
