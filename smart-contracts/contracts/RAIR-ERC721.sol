// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IERC2981.sol";
import "./IRAIR-ERC721.sol";
import 'hardhat/console.sol';

/// @title  Extended ERC721Enumerable contract for the RAIR system
/// @notice Uses ERC2981 and ERC165 for standard royalty info
/// @notice Uses AccessControl for the minting mechanisms
/// @author Juan M. Sanchez M.
/// @dev    Ideally generated by a RAIR Token Factory
contract RAIR_ERC721 is IERC2981, ERC165, IRAIR_ERC721, ERC721Enumerable, AccessControlEnumerable {
	struct collection {
		uint startingToken;
		uint endingToken;
		uint mintableTokens;
		uint enableResaleAt;
		string name;
	}

	collection[] private _collections;

	bytes32 public constant CREATOR = keccak256("CREATOR");
	bytes32 public constant MINTER = keccak256("MINTER");

	mapping(uint => uint) public tokenToCollection;

	address private _factory;
	uint16 private _royaltyFee;

	/// @notice	Token's constructor
	/// @dev	RAIR is still the ERC721's symbol
	/// @param	_creatorAddress	Address of the media's creator
	/// @param	_creatorRoyalty	Fee given to the creator on every sale
	constructor(
		string memory _contractName,
		address _creatorAddress,
		uint16 _creatorRoyalty
	) ERC721(_contractName, "RAIR") {
		_factory = msg.sender;
		_royaltyFee = _creatorRoyalty;
		_setRoleAdmin(MINTER, CREATOR);
		_setupRole(CREATOR, _creatorAddress);
		_setupRole(MINTER, _creatorAddress);
	}

	/// @notice	Creates a collection
	/// @dev	Only a CREATOR can call this function
	/// @param	_collectionName Name of the collection
	/// @param	_copies			Amount of tokens inside the collection
	function createCollection(string memory _collectionName, uint _copies, uint _resaleAt) public onlyRole(CREATOR) {
		require(_copies >= _resaleAt, "ERC721: Resale start should be less than the total amount of copies");
		uint lastToken;
		if (_collections.length == 0) {
			lastToken = 0;
		} else {
			lastToken = _collections[_collections.length - 1].endingToken;
		}
		collection storage newCollection = _collections.push();
		newCollection.startingToken = lastToken;
		newCollection.endingToken = newCollection.startingToken + _copies;
		newCollection.name = string(_collectionName);
		newCollection.mintableTokens = _copies;
		newCollection.enableResaleAt = _resaleAt;
		emit CollectionCreated(_collections.length - 1, _collectionName, _copies);
		if (_resaleAt == 0) {
			emit TransfersEnabled(_collections.length - 1, _collectionName);
		}
	}

	/// @notice	Returns the number of collections on the contract
	/// @dev	Use with get collection to list all of the collections
	function getCollectionCount() external view override(IRAIR_ERC721) returns(uint) {
		return _collections.length;
	}

	/// @notice	Returns information about a collection
	/// @param	index	Index of the collection
	function getCollection(uint index) external override(IRAIR_ERC721) view returns(uint startingToken, uint endingToken, uint mintableTokensLeft, string memory collectionName) {
		collection memory selectedCollection =  _collections[index];
		return (selectedCollection.startingToken, selectedCollection.endingToken, selectedCollection.mintableTokens, selectedCollection.name);
	}

	/// @notice	Very inefficient way of verifying if an user owns a token within a collection
	/// @param	owner			User to search
	/// @param	collectionIndex	Collection to search
	function hasTokenInCollection(address owner, uint collectionIndex) public view returns (bool) {
		for (uint i = 0; i < balanceOf(owner); i++) {
			if (tokenToCollection[tokenOfOwnerByIndex(owner, i)] == collectionIndex) {
				return true;
			}
		}
		return false;
	}

	/// @notice	Returns the token index inside the collection
	/// @param	token	Token ID to find
	function tokenToCollectionIndex(uint token) public view returns (uint tokenIndex) {
		return token - _collections[tokenToCollection[token]].startingToken;
	} 

	/// @notice	Mints new Tokens for A COLLECTION
	/// @param	to				Address of the new Owner
	/// @param	collectionID	Index of the collection to mint
	function mint(address to, uint collectionID) external override(IRAIR_ERC721) onlyRole(MINTER) {
		collection storage currentCollection = _collections[collectionID];
		require(currentCollection.mintableTokens > 0, "RAIR ERC721: Cannot mint tokens from this collection");
		//console.log('Minted', currentCollection.endingToken - currentCollection.mintableTokens, 'for', to);
		_safeMint(to, currentCollection.endingToken - currentCollection.mintableTokens);
		tokenToCollection[currentCollection.endingToken - currentCollection.mintableTokens] = collectionID;
		currentCollection.mintableTokens--;
		if (currentCollection.enableResaleAt > 0) {
			currentCollection.enableResaleAt--;
			if (currentCollection.enableResaleAt == 0) {
				emit TransfersEnabled(collectionID, currentCollection.name);
			}
		}
		if (currentCollection.mintableTokens == 0) {
			emit CollectionCompleted(collectionID, currentCollection.name);
		}
	}

	/// @notice Returns the fee for the NFT sale
	/// @param _tokenId - the NFT asset queried for royalty information
	/// @param _value - the sale price of the NFT asset specified by _tokenId
	/// @param _data - information used by extensions of this ERC.
	///                Must not to be used by implementers of EIP-2981 
	///                alone.
	/// @return _receiver - address of who should be sent the royalty payment
	/// @return _royaltyAmount - the royalty payment amount for _value sale price
	/// @return _royaltyPaymentData - information used by extensions of this ERC.
	///                               Must not to be used by implementers of
	///                               EIP-2981 alone.
	function royaltyInfo(uint256 _tokenId, uint256 _value, bytes calldata _data)
		external view override(IRAIR_ERC721, IERC2981) returns (address _receiver, uint256 _royaltyAmount, bytes memory _royaltyPaymentData) {
		return (getRoleMember(CREATOR, 0), (_value * _royaltyFee) / 100000, abi.encodePacked(_tokenId));
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165, AccessControlEnumerable, ERC721Enumerable, IERC2981) returns (bool) {
		return interfaceId == type(IERC2981).interfaceId
			|| super.supportsInterface(interfaceId);
	}

	/// @notice Hook being called before every transfer
	/// @dev	Transfer locking happens here!
	/// @param	_from		Token's original owner
	/// @param	_to			Token's new owner
	/// @param	_tokenId	Token's ID
	function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId) internal virtual override(ERC721Enumerable) {
		if (_from != address(0) && _to != address(0)) {
			require(_collections[tokenToCollection[_tokenId]].enableResaleAt == 0, "RAIR ERC721: Transfers for this collection haven't been enabled");
		} 
		super._beforeTokenTransfer(_from, _to, _tokenId);
	} 
}