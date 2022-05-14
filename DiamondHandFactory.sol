// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DiamondVault.sol";

/// @title A factory to create DiamondVaults (Used for Diamond-Handing assets through time-locks) 
/// @author Momo Labs

contract DiamondHandFactory is Ownable {
    using Counters for Counters.Counter;
    /// @dev Number of DiamondVaults
    Counters.Counter private vaultCount;

    /// @dev Mapping of vault number to vault contract address
    mapping(uint256 => address) vaults;

    /// @dev Mapping of user's wallet to vault number
    mapping(address => uint256) userToVault;

    /// @dev the DiamondVault logic contract
    address public immutable logic;

    address public DIAMONDPASS; //Address of DiamondPass NFT. Holders can create Diamond-Hands for free
    uint256 public PRICE = 0.01 ether;
    uint256 public minBreakPrice = 0.1 ether;   //Minimum emergency unlock price
    mapping (bytes32 => bool) isDiamondSpecial;    //Mapping an NFT project's contract address to whether or not they are on the diamondSpecial. Can be used to reward top communities with free Diamond-Hand usage

    event DiamondVaultCreated(address indexed vaultAddress, uint256 indexed vaultCount);
    event ReceivedPayment(address indexed sender);

    constructor() {
        //Deploys a new DiamondVault contract and sets it as the immutable implementation for proxies
        logic = address(new DiamondVault());
    }

    /**
    * @notice Creates a DiamondVault through proxy cloning
    * @return address of the created DiamondVault
    */
    function createDiamondVault() external returns(address) {
        address payable vaultAddress = payable(Clones.clone(logic));
        DiamondVault(vaultAddress).initialize(vaultCount.current(), msg.sender, address(this));

        emit DiamondVaultCreated(vaultAddress, vaultCount.current());
        
        vaults[vaultCount.current()] = vaultAddress;
        userToVault[msg.sender] = vaultCount.current();
        vaultCount.increment();
        return vaultAddress;
    }

    receive() external payable {
        emit ReceivedPayment(msg.sender);
    }

    /**
    * @dev Fetch user's vault address
    * @param _walletAddress Address of user
    * @return address of user's vault
    */
    function getVaultAddress(address _walletAddress) public view returns(address) {
        return vaults[userToVault[_walletAddress]];
    }

    /**
    * @dev Fetch total number of vaults
    * @return uint256 number of vaults
    */
    function getVaultCount() public view returns(uint256) {
        return vaultCount.current();
    }

    /**
    * @dev See if specified contract address isDiamondSpecial
    * @param _contractAddress NFT's contract address
    * @param _tokenId Token ID of NFT (used for ERC1155 NFTs)
    * @return bool If address isDiamondSpecial
    */
    function checkDiamondSpecial(address _contractAddress, uint256 _tokenId) public view returns(bool) {
        return isDiamondSpecial[keccak256(abi.encodePacked(_contractAddress, _tokenId))];
    }

    /**
    * @dev Withdraw ETH
    */
    function withdraw() external onlyOwner(){
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    /**
    * @dev Set a list of NFT contract addresses as true/false for isDiamondSpecial
    * @param _contractAddresses Array of contract addresses
    * @param _tokenIds Array of token IDs (used for ERC1155 NFTs)
    * @param isOnList Boolean, whether or not these addresses should be mapped to true or false in isDiamondSpecial
    */
    function setDiamondSpecial(address[] memory  _contractAddresses, uint256[] memory _tokenIds, bool isOnList) external onlyOwner {
        uint256 i;
        for (i = 0; i < _contractAddresses.length; i ++){
            isDiamondSpecial[keccak256(abi.encodePacked(_contractAddresses[i], _tokenIds[i]))] = isOnList;
        }
    }

     /**
    * @dev Set DIAMONDPASS NFT Address
    * @param _newAddress New address to be set
    */
    function setDiamondPassAddress(address _newAddress) external onlyOwner {
        DIAMONDPASS = _newAddress;
    }

    /**
    * @dev Set Price of Creating Diamond-Hand
    * @param _price of creating Diamond-Hand
    */
    function setPrice(uint256 _price) external onlyOwner {
        PRICE = _price ;
    }

    /**
    * @dev Set minimum emergency unlock price when Diamond-Handing
    * @param _minPrice New minimum emergency unlock price when creating a Diamond-Hand
    */
    function setMinBreakPrice(uint256 _minPrice) external onlyOwner {
        minBreakPrice = _minPrice ;
    }

}