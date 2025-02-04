// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**************************************

    Scale Codec library

**************************************/

// xcm imports
import { ScaleCodec } from "ethereum-xcm-v3/src/utils/ScaleCodec.sol";

// base58 imports
import { Base58 } from "base58-solidity/contracts/Base58.sol";

// string imports
import { strings } from "stringutils/strings.sol";

// import of mc01/lib-blake-2b
import { LibBlake2b } from "lib-blake-2b/contracts/LibBlake2b.sol";

// -----------------------------------------------------------------------
//              Extension to ScaleCodec.sol that introduces:
//                  - encoding unsigned integers
//                  - encoding strings
//                  - encoding eth address
//                  - encoding option of eth address
//                  - encoding substrate account id
//                  - encoding option of account id
// -----------------------------------------------------------------------

/// @notice This contract is an utility complementing ScaleCodec.sol for handling encoding in Substrate.
library LibScaleCodec {
    // -----------------------------------------------------------------------
    //                              Libraries
    // -----------------------------------------------------------------------

    using strings for *;

    // -----------------------------------------------------------------------
    //                              Errors
    // -----------------------------------------------------------------------

    error TooBigNumber(uint256 number);
    error TooLongString(string text);
    error ReservedFormatSS58(uint8 format);
    error InvalidAddressLength(uint256 length);
    error InvalidChecksum(bytes checksum, uint8 checksumLength, bytes decodedAddress, uint8 decodedLength);

    // -----------------------------------------------------------------------
    //                              Encode: Uint256
    // -----------------------------------------------------------------------

    function encodeU256U128(uint256 _content) internal pure returns (bytes16) {
        // ensure number is not too big
        if (_content > type(uint128).max) {
            revert TooBigNumber(_content);
        }

        // return uint256 from solidity encoded as uint128 in substrate
        return ScaleCodec.encodeU128(uint128(_content));
    }

    function encodeU256U64(uint256 _content) internal pure returns (bytes8) {
        // ensure number is not too big
        if (_content > type(uint64).max) {
            revert TooBigNumber(_content);
        }

        // return uint256 from solidity encoded as uint64 in substrate
        return ScaleCodec.encodeU64(uint64(_content));
    }

    function encodeU256U32(uint256 _content) internal pure returns (bytes4) {
        // ensure number is not too big
        if (_content > type(uint32).max) {
            revert TooBigNumber(_content);
        }

        // return uint256 from solidity encoded as uint32 in substrate
        return ScaleCodec.encodeU32(uint32(_content));
    }

    // -----------------------------------------------------------------------
    //                              Encode: String
    // -----------------------------------------------------------------------

    function encodeString(string memory _content) internal pure returns (bytes memory) {
        // ensure string is not too long
        uint256 length_ = _content.toSlice().len();
        if (length_ > type(uint8).max) {
            revert TooLongString(_content);
        }

        // return
        return abi.encodePacked(uint8(length_ * 4), abi.encodePacked(_content));
    }

    // -----------------------------------------------------------------------
    //                              Encode: EthAddress
    // -----------------------------------------------------------------------

    function encodeEthAddress(address _content) internal pure returns (bytes memory) {
        // return
        return abi.encodePacked(_content);
    }

    // -----------------------------------------------------------------------
    //                              Encode: Option<EthAddress>
    // -----------------------------------------------------------------------

    function encodeOptionEthAddress(address _content) internal pure returns (bytes memory) {
        // check if empty option
        if (_content == address(0)) {
            // return empty option
            return hex"00";
        } else {
            // return 01 prefix as non-empty option and encode eth address
            return abi.encodePacked(hex"01", encodeEthAddress(_content));
        }
    }

    // -----------------------------------------------------------------------
    //                              Encode: AccountId
    // -----------------------------------------------------------------------

    // @dev Based on py-scale-codec decoding of ss58 to account id
    function encodeSubstrateAccountId(string memory _content) internal pure returns (bytes memory) {
        // vars
        uint8 ss58FormatLength_;
        uint8 ss58Format_;
        uint8 checksumLength_;

        // declare checksum prefix
        bytes memory checksumPrefix_ = "SS58PRE";

        // decode base58 address
        bytes memory decodedAddress_ = Base58.decode(bytes(_content));
        uint8 decodedLength_ = uint8(decodedAddress_.length);

        // address elements
        uint8 elementZero_ = uint8(decodedAddress_[0]);
        uint8 elementOne_ = uint8(decodedAddress_[1]);

        // set ss58 format
        if (elementZero_ & 0x0b0100_0000 != 0) {
            ss58FormatLength_ = 2;
            ss58Format_ = uint8((elementZero_ & (0x0b0011_1111 << 2)) | (elementOne_ >> 6) | (elementOne_ & (0x0b0011_1111 << 8)));
        } else {
            ss58FormatLength_ = 1;
            ss58Format_ = elementZero_;
        }

        // validate ss58 format
        if (_contains(uint256(ss58Format_), [uint256(46), uint256(47)])) {
            revert ReservedFormatSS58(ss58Format_);
        }

        // set checksum length
        if (_contains(decodedLength_, [uint256(3), uint256(4), uint256(6), uint256(10)])) {
            checksumLength_ = 1;
        } else if (
            _contains(decodedLength_, [uint256(5), uint256(7), uint256(11), uint256(34 + ss58FormatLength_), uint256(35 + ss58FormatLength_)])
        ) {
            checksumLength_ = 2;
        } else if (_contains(decodedLength_, [uint256(8), uint256(12)])) {
            checksumLength_ = 3;
        } else if (_contains(decodedLength_, [uint256(9), uint256(13)])) {
            checksumLength_ = 4;
        } else if (decodedLength_ == 14) {
            checksumLength_ = 5;
        } else if (decodedLength_ == 15) {
            checksumLength_ = 6;
        } else if (decodedLength_ == 16) {
            checksumLength_ = 7;
        } else if (decodedLength_ == 17) {
            checksumLength_ = 8;
        } else {
            revert InvalidAddressLength(decodedLength_);
        }

        // build checksum
        bytes memory checksum_ = LibBlake2b.blake2b_512(
            abi.encodePacked(checksumPrefix_, _getBytesSlice(decodedAddress_, 0, decodedLength_ - checksumLength_))
        );

        // validate checksum
        if (
            keccak256(_getBytesSlice(checksum_, 0, checksumLength_)) !=
            keccak256(_getBytesSlice(decodedAddress_, decodedLength_ - checksumLength_, decodedLength_))
        ) {
            revert InvalidChecksum(checksum_, checksumLength_, decodedAddress_, decodedLength_);
        }

        // return
        return _getBytesSlice(decodedAddress_, ss58FormatLength_, decodedAddress_.length - checksumLength_);
    }

    // -----------------------------------------------------------------------
    //                              Encode: Option<AccountId>
    // -----------------------------------------------------------------------

    function encodeOptionSubstrateAccountId(string memory _content) internal pure returns (bytes memory) {
        // check if empty option
        if (bytes(_content).length == 0) {
            // return empty option
            return hex"00";
        } else {
            // return 01 prefix as non-empty option and encode account id
            return abi.encodePacked(hex"01", encodeSubstrateAccountId(_content));
        }
    }

    // -----------------------------------------------------------------------
    //                              Internal: Contains
    // -----------------------------------------------------------------------

    function _contains(uint256 _item, uint256[2] memory _collection) internal pure returns (bool) {
        // find in 2 element collection
        for (uint256 i = 0; i < 2; i++) {
            if (_item == _collection[i]) return true;
        }
        return false;
    }

    function _contains(uint256 _item, uint256[3] memory _collection) internal pure returns (bool) {
        // find in 3 element collection
        for (uint256 i = 0; i < 3; i++) {
            if (_item == _collection[i]) return true;
        }
        return false;
    }

    function _contains(uint256 _item, uint256[4] memory _collection) internal pure returns (bool) {
        // find in 4 element collection
        for (uint256 i = 0; i < 4; i++) {
            if (_item == _collection[i]) return true;
        }
        return false;
    }

    function _contains(uint256 _item, uint256[5] memory _collection) internal pure returns (bool) {
        // find in 5 element collection
        for (uint256 i = 0; i < 5; i++) {
            if (_item == _collection[i]) return true;
        }
        return false;
    }

    // -----------------------------------------------------------------------
    //                              Internal: Slices
    // -----------------------------------------------------------------------

    function _getBytesSlice(bytes memory _input, uint256 _start, uint256 _end) public pure returns (bytes memory) {
        // result
        bytes memory result_ = new bytes(_end - _start);

        // build slice of bytes
        for (uint256 i = 0; i < _end - _start; i++) {
            result_[i] = _input[_start + i];
        }

        // return
        return result_;
    }
}
