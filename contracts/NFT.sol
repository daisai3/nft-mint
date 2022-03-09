//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    mapping(address => bool) public whitelisted;

    mapping(address => uint256) public discountMints;

    uint256 public publicMintPrice = 1 ether;

    uint256 public whitelistMintPrice = 0.5 ether;

    uint256 public constant MAX_SUPPLY = 500;

    uint256 public tokenIdPointer;

    uint256 public immutable whitelistRegisterEndTimestamp;

    uint256 public immutable whitelistSaleEndTimestamp;

    string public prerevealURI;

    string public baseURI;

    uint256 public offsetIndex;

    constructor(
        uint256 _whitelistRegisterEndTimestamp,
        uint256 _whitelistSaleEndTimestamp,
        string memory _prerevealURI
    ) ERC721("NFT", "NFT") {
        require(
            _whitelistSaleEndTimestamp > _whitelistRegisterEndTimestamp,
            "invalid timestamp"
        );
        require(
            _whitelistRegisterEndTimestamp > block.timestamp,
            "invalid timestamp"
        );
        whitelistRegisterEndTimestamp = _whitelistRegisterEndTimestamp;
        whitelistSaleEndTimestamp = _whitelistSaleEndTimestamp;

        prerevealURI = _prerevealURI;
    }

    function publicMint(uint256 _qty) public payable nonReentrant {
        uint256 totalPrice = _qty * publicMintPrice;
        require(totalPrice == msg.value, "insufficient funds");

        mint(msg.sender, _qty);
    }

    function whitelistMint(uint256 _qty) public payable nonReentrant {
        require(
            block.timestamp > whitelistRegisterEndTimestamp &&
                block.timestamp <= whitelistSaleEndTimestamp,
            "whiteliste sale is not active"
        );
        address user = msg.sender;
        require(whitelisted[user], "not whitelisted");

        uint256 totalPrice = _qty * whitelistMintPrice;
        require(totalPrice == msg.value, "insufficient funds");

        require(
            discountMints[user] + _qty <= 10,
            "can't mint more than 10 tokens at a discount"
        );
        discountMints[user] += _qty;

        mint(user, _qty);
    }

    function mint(address _user, uint256 _qty) internal {
        require(_qty > 0, "minimum 1 nft");
        require(_qty <= 10, "max 10 per tx");
        require(tokenIdPointer + _qty <= MAX_SUPPLY, "out of stock");

        for (uint256 i = 0; i < _qty; i++) {
            _safeMint(_user, tokenIdPointer + 1 + i);
        }
        tokenIdPointer += _qty;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 _id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_id),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory currentBaseURI = _baseURI();
        bool revealed = bytes(currentBaseURI).length > 0;

        if (revealed) {
            uint256 offsetId = (_id + MAX_SUPPLY - offsetIndex) % MAX_SUPPLY + 1;
            return
                string(abi.encodePacked(currentBaseURI, offsetId.toString()));
        }
        return prerevealURI;
    }

    function addWhitelist(address[] calldata _users) public onlyOwner {
        require(
            block.timestamp <= whitelistRegisterEndTimestamp,
            "can't whitelist users"
        );
        for (uint256 i = 0; i < _users.length; i++) {
            whitelisted[_users[i]] = true;
        }
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        require(bytes(baseURI).length == 0, "baseURI already set");

        baseURI = _newBaseURI;

        offsetIndex = uint256(blockhash(block.number)) % MAX_SUPPLY;

        if (offsetIndex == 0) {
            offsetIndex = 1;
        }
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
