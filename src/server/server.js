import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


const gas = 6721975;
const oracles = [];

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

let registeredAirline;
let accounts;
// let oracles;

const airlineName = 'InterCon';
const flights = [
    {
        name: 'A1111',
        timestamp: 1633963343,
    },
    {
        name: 'B2222',
        timestamp: 1633943343,
    },
    {
        name: 'C3333',
        timestamp: 1633993343,
    },
    {
        name: 'D4444',
        timestamp: 1634193343,
    },
    {
        name: 'E5555',
        timestamp: 1634293343,
    }
];

let statusCodes = {
  STATUS_CODE_UNKNOWN: 0,
  STATUS_CODE_ON_TIME: 10,
  STATUS_CODE_LATE_AIRLINE: 20,
  STATUS_CODE_LATE_WEATHER: 30,
  STATUS_CODE_LATE_TECHNICAL: 40,
  STATUS_CODE_LATE_OTHER: 50,
};

console.log("Application contract is deployed on address: ", config.appAddress);
console.log("Web3 v: ", web3.version);

(async() => {
  accounts = await web3.eth.getAccounts();
  web3.eth.defaultAccount = web3.eth.accounts[0];
  registeredAirline = accounts[1];
  //populate object with 10 properties as empty array, will serve later for saving oracles according to their indexes
  for(let i = 0; i < 10; i++) {
    oracles[i] = [];
  }

  await registerAirline();
  await registerOracles();
  await registerFlights();
})();

async function registerAirline() {
  try {
    let accounts = await web3.eth.getAccounts();
    let airlineAddress = accounts[0];
    const result = await flightSuretyApp.methods.registerAirline(airlineName, airlineAddress).send({ from: airlineAddress, value: web3.utils.toWei('10', 'ether')});
    console.log("registerAirline result", result);
  } catch (e) {
    console.log("register airline error: ", e);
  }
}

async function registerOracles() {
  try {
    console.log("accounts", accounts);
    for (let i = 1; i < accounts.length; i++) {
      console.log("account", accounts[i]);
      await flightSuretyApp.methods.registerOracle().send({
        value: web3.utils.toWei('1', 'ether'),
        from: accounts[i]
      });
      console.log("registered account***")
      const results = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]});
      console.log("fired results");
      for(let j = 0; j < results.length; j++) {
        oracles[results[index]].push(accounts[i]);
      }
    }
    console.log(`${accounts.length} oracles registered`);
  } catch (e) {
    console.log("error while registering oracle: ", e);
  }
}

async function registerFlights() {
  try {
    for(let i = 0; i < flights.length; i++) {
      await flightSuretyApp.methods.registerFlight(airlineName, flights[i].name, flights[i].timestamp).send({ from: registeredAirline, gas });
      console.log(`flight ${i} registered`);
    }
  } catch (e) {
    console.log("error while registering flights: ", e);
  }
}


async function updateFlightStatus(index, airline, flight, timestamp) {
  let requestedOracles = [];

  oracles
    .filter((oracle) => oracle.indexes.includes(index))
    .forEach(() => {
      const statusCode = generateRandomStatusCode();
      flightSuretyApp.methods
        .submitOracleResponse(index, airline, flight, timestamp, statusCode)
        .send(({from: oracles.address, gas }))
        .catch((err) => console.log("Submiting oracle response ended up with error: ", err));
    })

}

function generateRandomStatusCode() {
  let statusCodes = [0, 10, 20, 30, 40, 50];
  return statusCodes[Math.floor(Math.random() * statusCodes.length + 1)];
}


flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
});

const app = express();

app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

export default app;