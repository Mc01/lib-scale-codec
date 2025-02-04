# Lib Scale Codec

## Installation
```sh
npm i git+https://github.com/Mc01/lib-scale-codec.git
```

## Usage

Import and use directly in your Diamond Proxy:
```solidity
// numbers
bytes memory u128_ = LibScaleCodec.encodeU256U128(uint256(1)); // u128
bytes memory u64_ = LibScaleCodec.encodeU256U64(uint256(1)); // u64
bytes memory u32_ = LibScaleCodec.encodeU256U32(uint256(1)); // u32

// string
bytes memory string_ = LibScaleCodec.encodeString(""); // Vec<u8>

// eth address
address ethAddress_ = msg.sender;
bytes memory address_ = LibScaleCodec.encodeEthAddress(ethAddress_); // [u8; 20]
bytes memory optionAddress_ = LibScaleCodec.encodeOptionEthAddress(ethAddress_); // Option<[u8; 20]>

// account id
string memory ss58Address_ = "5GKWfWMDt1BdvT9Bj2KpUC7zLmK3hJJpaCTJ7naSLeFw5eJc"
bytes memory accountId_ = LibScaleCodec.encodeSubstrateAccountId(ss58Address_); // AccountId
bytes memory optionAccountId_ = LibScaleCodec.encodeOptionSubstrateAccountId(ss58Address_); // Option<AccountId>
```
