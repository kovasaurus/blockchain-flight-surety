// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

library SharedData {
    enum AirlineStatus {
        PENDING,
        REGISTERED,
        FUNDED
    }

    struct Airline {
        string name;
        address ownerAddress;
        AirlineStatus status;
        uint256 votes;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        string name;
        uint256 time;        
        string airline;
    }

    struct Insurance {
        bool isInsured;
        address airline;
        string flight;
        address passenger;
        uint256 amount;
    }
}