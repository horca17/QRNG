// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts@1.2.0/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.2.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts@1.2.0/src/v0.8/shared/interfaces/LinkTokenInterface.sol";


contract ExternalAdapterConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    uint256 private constant fee = (1 * LINK_DIVISIBILITY) / 10; // 0.1 * 10**18
    bytes32 private jobId;
    uint256 public result;
    bytes32 private accessCodeHash; // Hash del código secreto

    event RequestRandomNumberFulfilled(
        bytes32 indexed requestId,
        uint256 indexed result
    );

    constructor(bytes32 _accessCodeHash) ConfirmedOwner(msg.sender) {
        _setChainlinkToken(0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846);
        accessCodeHash = _accessCodeHash; // Guardar el hash del código secreto
    }

    function setAccessCodeHash(bytes32 _newHash) public onlyOwner {
        accessCodeHash = _newHash;
    }

    function requestRandomNumber(
        address _oracle,
        string memory _jobId,
        string memory _accessCode
    ) public {
        require(
            keccak256(abi.encodePacked(_accessCode)) == accessCodeHash,
            "Invalid access code"
        );

        Chainlink.Request memory req = _buildChainlinkRequest(
            stringToBytes32(_jobId),
            address(this),
            this.fulfill.selector
        );
        req._add(
            "get",
            "https://9b497939447c7727817519b3436736d4.serveo.net/generate_random"
        );
        req._add("path", "");
        req._addInt("times", 1);
        _sendChainlinkRequestTo(_oracle, req, fee);
    }

    function fulfill(
        bytes32 _requestId,
        uint256 _result
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestRandomNumberFulfilled(_requestId, _result);
        result = _result;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) public onlyOwner {
        _cancelChainlinkRequest(
            _requestId,
            _payment,
            _callbackFunctionId,
            _expiration
        );
    }

    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 convertedResult) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            convertedResult := mload(add(source, 32))
        }
    }
}
