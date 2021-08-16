// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "./SafeMath.sol";
import "./SharedData.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    uint256 private registeredAirlineNum = 0;
    uint256 private registeredFlightNum = 0;

    mapping(string => SharedData.Airline) private airlines;
    mapping(address => string) private airlineAddressMap;
    mapping(string => address[]) private airlineVoters;
    mapping(string => uint256) private airlineFunds;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(SharedData.Airline airline);
    event AirlineFunded(string airlineName, uint256 amount);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor () {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) {
        return operational;
    }

    function isRegistered(string memory airlineName) 
        public
        view
        returns(bool) {
            return airlines[airlineName].ownerAddress != address(0);
    }

    function eligibleVote(string memory airlineName) 
        external
        view
        returns(bool) {
            return airlines[airlineName].votes < registeredAirlineNum.div(2);
        }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) 
        external
        requireContractOwner {
            operational = mode;
    }

    function getNumberOfRegisteredAirlines() external view returns(uint256) {
        return registeredAirlineNum;
    }

    function isOwner() external view returns(bool) {
        return msg.sender == contractOwner;
    }

    function getAirlineVotes(string memory airlineName) external view returns(uint256) {
        return airlines[airlineName].votes;
    }

    function getAirlineVoters(string memory airlineName) external view returns(address[] memory) {
        return airlineVoters[airlineName];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    */   
    function registerAirline (
        address airlineAddress,
        string memory airlineName,
        SharedData.AirlineStatus status,
        uint256 votes
    ) external requireOperational {
        SharedData.Airline memory newAirline = SharedData.Airline(airlineName, airlineAddress, status, votes);
        airlines[airlineName] = newAirline;
        registeredAirlineNum = registeredAirlineNum.add(1);
        airlineAddressMap[airlineAddress] = airlineName;
        emit AirlineRegistered(newAirline);
    }

    function vote(
        string memory airlineName
    ) external requireOperational {
        SharedData.Airline memory airline = airlines[airlineName];
        require(airline.votes < 5, "Unable to vote for airline");
        airline.votes = airline.votes.add(1);

        airlineVoters[airlineName].push(msg.sender);
    } 


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund () public payable {
       payable(address(this)).transfer(msg.value);
    }

    /**
     * Fund airline (doesn't have to be from account that owns airline)
     */
    function fundAirline (string memory airlineName) 
        external payable {
            airlineFunds[airlineName] = airlineFunds[airlineName].add(msg.value);
            emit AirlineFunded(airlineName, msg.value);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() external payable{
        fund();
    }

    receive() external payable{
        fund();
    }


}

