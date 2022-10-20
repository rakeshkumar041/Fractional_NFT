// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FractionalNFT is ERC721URIStorage, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter;

    struct _fnft{
        uint256 tokenId;
        uint256 price;
        uint256 shares;
        uint256 shareValue;
        address fractionalToken;
        address payable owner;
    }

    mapping(uint256 => _fnft) public FNFT;

    constructor() ERC721("FractionalNFT", "FNFT") {}

    function safeMint(address to) public onlyOwner {
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());
    }

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //is the caller of this function the owner of the NFT?
	modifier isNFTOwner(uint256 _tokenId) {
		require(msg.sender == ownerOf(_tokenId));
		_;
	}

    function mint(address _to, string memory tokenURI_) external onlyOwner returns(uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        return tokenId;
    }

    function lockNFT(uint256 _tokenID, uint256 _totalFractionalTokens, uint256 _price) external onlyOwner isNFTOwner(_tokenID) {
        //transfer NFT to smart contract
        _transfer(msg.sender, address(this), _tokenID);
        //Create a ERC20 Token Contract for this newly minted NFT
        FToken _ftoken = (new FToken)();                                          //initialize
        //mint the fractional tokens and send it to the owner of this NFT           
        _ftoken.mint(msg.sender, _totalFractionalTokens);
        _fnft memory fnft = _fnft(_tokenID, _price, _totalFractionalTokens, _price.div(_totalFractionalTokens), address(_ftoken), payable(msg.sender));
        FNFT[_tokenID]  = fnft;                                  
    }

    function sellShares(uint256 _tokenID, uint256 _sharesToSell) public nonReentrant payable{
        _fnft memory fnft = FNFT[_tokenID];
        require(_sharesToSell <= fnft.shares, "Cannot sell shares more than allocated");
        require(FToken(fnft.fractionalToken).balanceOf(msg.sender) >= _sharesToSell,
            "Insufficient shares"
        );

        uint256 _amount = fnft.shareValue.mul(_sharesToSell);
        uint256 _balance = address(this).balance;
        require(_amount <= _balance, "Insufficient fund in contract");
        payable(msg.sender).transfer(_amount);

        FToken(fnft.fractionalToken).transferFrom(msg.sender, address(this), _sharesToSell);
    }

    function buyShares(uint256 _tokenID, uint256 _sharesToBuy) public nonReentrant payable {
        _fnft memory fnft = FNFT[_tokenID];
        require(_sharesToBuy <= fnft.shares, "Cannot buy shares more than allocated");
        require(FToken(fnft.fractionalToken).balanceOf(address(this)) >= _sharesToBuy,
            "Insufficient shares"
        );
        require(msg.value >= fnft.shareValue.mul(_sharesToBuy),
            "Insufficient funds"
        );
        
        uint256 _amount = fnft.shareValue.mul(_sharesToBuy);
        payable(address(this)).transfer(_amount);

        //Update NFT Owner if all the shares are purchased
        if (fnft.shares == FToken(fnft.fractionalToken).balanceOf(msg.sender) + _sharesToBuy) {
            FNFT[_tokenID].owner = payable(msg.sender);
        }

        FToken(fnft.fractionalToken).transfer(payable(msg.sender), _sharesToBuy);
    }

     /// @notice an external function to burn all ERC20 tokens to receive the ERC721 token
    function releaseNFT(uint256 _tokenID) external {
        _fnft memory fnft = FNFT[_tokenID];
        require(FToken(fnft.fractionalToken).balanceOf(msg.sender) >= FToken(fnft.fractionalToken).totalSupply(), "All Fractional Tokens are needed to redeem the NFT");

        //Burn all fractional NFT of sender
        FToken(fnft.fractionalToken).burn(msg.sender, FToken(fnft.fractionalToken).balanceOf(msg.sender));
        
        // transfer erc721 to redeemer
        _transfer(address(this), msg.sender, _tokenID);

        delete FNFT[_tokenID];

    }

    receive() external payable {
        //TODO
    }

    fallback() external payable {
        //TODO
    }
}

contract FToken is ERC20, Ownable {
    constructor() ERC20("Fractional Token", "FToken") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public onlyOwner {
        _burn(to, amount);
    }
}
