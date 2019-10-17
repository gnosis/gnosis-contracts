pragma solidity ^0.5.0;
import "../Oracles/Oracle.sol";


contract TellorInterface {
		function getFirstVerifiedDataAfter(uint _requestId, uint _timestamp) returns (bool,uint,uint);
}



contract TellorOracle is Oracle{

    /*
     *  Events
     */
    event OutcomeAssignment(int outcome);

    /*
     *  Storage
     */
    address public tellorContract;
    uint public requestId;
    uint public _endDate;
    bool public isSet;
    int public outcome;


    /*
     *  Public functions
     */
    function setTellorContract(address _tellorContract, uint _requestId, uint _endDate)
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
    }

    /// @dev Sets event outcome
    /// @param _outcome Event outcome
    function setOutcome()
        public
    {
        // Result is not set yet
        require(!isSet);
        require(_requestId != 0);
        bool _didGet;
        uint _value;
        uint _time;
        _didGet,_value,_time = TellorInterface(tellorContract).getFirstVerifiedDataAfter(requestId,_endDate);
        if(_didGet){
        	outcome = _value;
        	isSet = true;
        	emit OutcomeAssignment(_outcome);
        }
    }

    /// @dev Returns if winning outcome is set
    /// @return Is outcome set?
    function isOutcomeSet()
        public
        view
        returns (bool)
    {
        return isSet;
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
}
