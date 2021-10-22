// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "./SafeMath.sol";
import "./FlightSuretyData.sol";
import "./SharedData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData dataContract;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private constant AIRLINE_REGISTRATION_VOTING_THRESHOLD = 4;
    uint256 private constant AIRLINE_REGISTRATION_FEE = 10 ether;

    address private contractOwner;          // Account used to deploy contract

    // Oracle data
    uint8 private nonce = 0;    // Incremented to add pseudo-randomness at various points
    uint256 public constant REGISTRATION_FEE = 1 ether;  // Fee to be paid when registering oracle
    uint256 private constant MIN_RESPONSES = 3;  // Number of oracles that must respond for valid status


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }



    mapping(string => SharedData.Flight) private flights;
    mapping(address => Oracle) private oracles;     // Track all registered oracles
    
    mapping(bytes32 => ResponseInfo) private oracleResponses;  // Track all oracle responses // Key = hash(index, flight, timestamp)


    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);
    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);
    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);
    event InsurancePurchased(string flight, address passanger, uint256 amount);
    event CreditWithdrawn(address passenger, uint256 amount);
 
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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner(){
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier correctInsuranceAmount() {
        require(msg.value > 0 ether && msg.value <= 1 ether, "Insurance needs to be between 0 and 1 ether");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address payable dataContractAddress) {
        dataContract = FlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            pure 
                            returns(bool) 
    {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(string calldata airlineName, address airlineAddress)
        external payable requireOperational {
            require(bytes(airlineName).length > 0, "Airline name can not be empty");
            if (dataContract.getNumberOfRegisteredAirlines() <= AIRLINE_REGISTRATION_VOTING_THRESHOLD) {
 //              require(dataContract.isOwner(), "Owner must register first 4 airlines");
               uint256 feeAmount = msg.value;
               require(isFeeSufficient(feeAmount), "Registration fee sent is too low");
               dataContract.registerAirline(
                   airlineAddress,
                   airlineName,
                   SharedData.AirlineStatus.REGISTERED,
                   5
               );
            } else {
                dataContract.registerAirline(
                   airlineAddress,
                   airlineName,
                   SharedData.AirlineStatus.PENDING,
                   0
               );
            }
    }

    /**
     * check whether sent amount matches registration fee
     */
    function isFeeSufficient(uint256 amount) 
        private 
        pure
        returns (bool) {
            return amount >= AIRLINE_REGISTRATION_FEE;
    }

    /**
     * Pay fee required to register airline
     */
    function fundAirline(string memory airlineName) 
        external
        payable
        requireOperational {
            // TODO make isRegistered function
            require(dataContract.isRegistered(airlineName), "Airline must be registered");
            require(isFeeSufficient(msg.value), "Fee provided is too low");
            dataContract.fundAirline(airlineName); // maybe add msg.value
    }

    function vote(string memory airlineName) 
        external
        requireOperational {
            require(bytes(airlineName).length > 0, "Require airline name to vote for");
            require(dataContract.isRegistered(airlineName), "Airline must be registered");
            require(dataContract.eligibleVote(airlineName), "Airline can not be voted for");
            address[] memory airlineVoters = dataContract.getAirlineVoters(airlineName);
            for (uint256 i = 0; i < airlineVoters.length; i++) {
                require(airlineVoters[i] != msg.sender, "You alreay voted for this airline");
            }
            dataContract.vote(airlineName);

    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(string memory airlineName, string memory flightName, uint256 flightTime)
        external
        requireOperational {
            require(bytes(airlineName).length > 0, "Require airline name");
            require(bytes(flightName).length > 0, "Require flight name");
            require(!dataContract.isFlightRegistered(flightName), "Flight already registered");
            require(dataContract.isAirlineOwner(airlineName, msg.sender), "Not airline owner");
            dataContract.registerFlight(airlineName, flightName, flightTime);
    }

    function buyInsurance(
        address airline,
        string memory flightName
    )
        external
        payable
        correctInsuranceAmount
        requireOperational {
            require(dataContract.isFlightRegistered(flightName), "Flight must be registered");
            dataContract.buy(flightName, airline, msg.sender, msg.value);
            emit InsurancePurchased(flightName, msg.sender, msg.value);
    }

    function withdrawCredit() public payable requireOperational {
        uint256 credit = dataContract.getPassengersCredit(msg.sender);
        payable(msg.sender).transfer(credit);
        emit CreditWithdrawn(msg.sender, credit);
    }

    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                public
    {
        require(dataContract.isFlightRegistered(flight));
        flights[flight].statusCode = statusCode;
        if(statusCode >= 20) {
            address[] memory flightInsurees = dataContract.getInsuredPassengers(flight);
            for(uint i = 0; i < flightInsurees.length; i++) {
                uint256 insuranceAmount = dataContract.getInsuranceAmount(flightInsurees[i], flight);
                uint256 credit = insuranceAmount.mul(3).div(2);
                dataContract.creditInsurees(flightInsurees[i], credit);
            }
        }
    }

    function getPassengersCredit(address passenger) public view returns(uint256) {
        return dataContract.getPassengersCredit(passenger);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus (
                            address airline,
                            string memory flight,
                            uint256 timestamp                            
                        )
                        external requireOperational {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key].requester = msg.sender;
        oracleResponses[key].isOpen = true;

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // Register an oracle with the contract
    function registerOracle ()
        external
        payable 
        requireOperational {
            // Require registration fee
            require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

            uint8[3] memory indexes = generateIndexes(msg.sender);

            oracles[msg.sender] = Oracle({
                                            isRegistered: true,
                                            indexes: indexes
                                        });
    }

    function getMyIndexes ()
        view
        external
        returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string memory flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
                        requireOperational
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
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

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
