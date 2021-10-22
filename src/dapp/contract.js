import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.gas = 6721975;
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            this.owner = accts[0];

            let counter = 1;

            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    async isOperational() {
       return this.flightSuretyApp.methods
            .isOperational()
            .send({ from: this.owner });
    }



    async fetchFlightStatus(flight, timestamp) {
        try {
            return this.flightSuretyApp.methods.fetchFlightStatus(this.airlines[0], flight, timestamp)
            .send({ from: this.owner });
        } catch (e) {
            console.log("error while fetching flight status: ", e);
        }
    }

    async buyInsurance(flight, value) {
        try {
            return this.flightSuretyApp.methods.buyInsurance(this.airlines[0], flight).send({
                from: this.passengers[0],
                value: this.web3.utils.toWei(value, 'Ether'),
                gas: this.gas
            })
        } catch (e) {
            console.log("error while buying insurance: ", e);
        }
    }

}
