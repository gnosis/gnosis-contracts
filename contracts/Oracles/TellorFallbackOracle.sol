//This takes an existing oracle and adds a Tellor fallback

//setOutcome takes a dispute period and then can fallback to Tellor

pragma solidity ^0.5.0;
import "../Oracles/Oracle.sol";
import "@gnosis.pm/util-contracts/contracts/Proxy.sol";

interface TellorInterface {
	function getFirstVerifiedDataAfter(uint _requestId, uint _timestamp) external returns(bool,uint,uint);
    function requestDataWithEther(uint _requestId) payable external;
    //function requestDataWithEther(string calldata _request, string calldata _symbol, uint256 _granularity, uint256 _tip) external payable;
}


contract CentralizedOracleData {

    /*
     *  Events
     */
    event OwnerReplacement(address indexed newOwner);
    event OutcomeAssignment(int outcome);

    /*
     *  Storage
     */
    address public owner;
    bytes public ipfsHash;
    bool public isSet;
    int public outcome;

    /*
     *  Modifiers
     */
    modifier isOwner () {
        // Only owner is allowed to proceed
        require(msg.sender == owner);
        _;
    }
}

contract TellorFallbackOracleProxy is Proxy, CentralizedOracleData {

    /// @dev Constructor sets owner address and IPFS hash
    /// @param _ipfsHash Hash identifying off chain event description
    constructor(address proxied, address _owner, bytes memory _ipfsHash)
        public
        Proxy(proxied)
    {
        // Description hash cannot be null
        require(_ipfsHash.length == 46);
        owner = _owner;
        ipfsHash = _ipfsHash;
    }
}

/// @title Centralized oracle contract - Allows the contract owner to set an outcome
/// @author Stefan George - <stefan@gnosis.pm>
contract TellorFallbackOracle is Proxied, Oracle, CentralizedOracleData {
	event OracleDisputed();
    /*
     *  Storage
     */
    address payable public tellorContract;
    uint public requestId;
    uint public endDate;
    uint public disputePeriod;
    uint public setTime;
    uint public disputeCost;
    bool public isDisputed;

    /*
     *  Public functions
     */
    /// @dev Replaces owner
    /// @param newOwner New owner
    function replaceOwner(address newOwner)
        public
        isOwner
    {
        // Result is not set yet
        require(!isSet);
        owner = newOwner;
        emit OwnerReplacement(newOwner);
    }

    /// @dev Sets event outcome
    /// @param _outcome Event outcome
    function setOutcome(int _outcome)
        public
        isOwner
    {
        // Result is not set yet
        require(!isSet);
        setTime = now; 
        isSet = true;
        outcome = _outcome;
        emit OutcomeAssignment(_outcome);
    }

    /// @dev Returns if winning outcome is set
    /// @return Is outcome set?
    function isOutcomeSet()
        public
        view
        returns (bool)
    {
    	if (now > setTime + disputePeriod /*+ duration*/){
    		return isSet;
    	}
    	else{
    		return false;
    	}

    }

    /// @dev Returns outcome
    /// @return Outcome
    function getOutcome()
        public
        view
        returns (int)
    {
        return outcome;
    }

    /*
     *  Public functions
     */
    function setTellorContract(address payable _tellorContract,uint _disputePeriod, uint _requestId, uint _endDate, uint _disputeCost)
        public
    {
        // Result is not set yet
        require(!isSet);
        require(_tellorContract == address(0));
        require(_requestId != 0);
        require(_tellorContract != address(0));
        require(_endDate > now);
        tellorContract = _tellorContract;
        requestId = _requestId;
        endDate = _endDate;
        disputeCost = _disputeCost;
        disputePeriod = _disputePeriod;
    }

    function dispute() public payable{
    	require(msg.value > disputeCost);
    	require(!isDisputed);
    	isDisputed = true;
    	isSet = false;
    	emit OracleDisputed();

    }

    /// @dev Sets event outcome
    function setTellorOutcome()
        public
    {
        // Result is not set yet
        require(!isSet);
        require(isDisputed);
        require(requestId != 0);
        bool _didGet;
        uint _value;
        uint _time;
        (_didGet,_value,_time) = TellorInterface(tellorContract).getFirstVerifiedDataAfter(requestId,endDate);
        if(_didGet){
        	outcome = int(_value);
        	isSet = true;
        	emit OutcomeAssignment(outcome);
        }
        else{
        	TellorInterface(tellorContract).requestDataWithEther(requestId).value(msg.value);
        }
    }
}
