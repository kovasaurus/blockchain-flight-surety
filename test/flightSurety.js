
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const { default: Web3 } = require('web3');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    //await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    await config.flightSuretyApp.registerAirline('Air Kosovo', accounts[1], {value: web3.utils.toWei('10', 'ether')});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {}
    let result = await config.flightSuretyData.isRegistered.call(newAirline);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) should not be able to register another airline if no funding was provided', async () => {
      let newAirlineAddress = accounts[2];
      
      try {
          await config.flightSuretyApp.registerAirline('Air Donji Miholjac', {from: accounts[1]});
      } catch (e) {}

      const registered = await config.flightSuretyData.isRegistered.call('Air Donji Miholjac');
      assert.equal(registered, false, "Funding wasnt provided");
  });
 
  it('(airline) owner can register initial 4 accounts without need for approval', async () => {
    let result = true;
    try {
        await config.flightSuretyApp.registerAirline('Air Strizivojna', accounts[2], {value: web3.utils.toWei('10', 'ether')});
        await config.flightSuretyApp.registerAirline('Air Sesvete', accounts[3], {value: web3.utils.toWei('10', 'ether')});
        await config.flightSuretyApp.registerAirline('Air Babina greda', accounts[4], {value: web3.utils.toWei('10', 'ether')});
    } catch (e) {
        console.log("e", e);
        result = false;
    }

    assert.equal(result, true, "Airline (owner) should be able to register 4 more airlines");

  });

  it('(airline) no-owner can register Airline after there are 5 registrated', async () => {
    let newAirlineAddress = accounts[5];
    let result = true;
    try {
        await config.flightSuretyApp.registerAirline('Air Highclub', newAirlineAddress, {from: newAirlineAddress, value: web3.utils.toWei('10', 'ether')});
    } catch(e) {
        console.log("e", e);
        result = false;
    }

    assert.equal(result, true, "Non-owner airline should be able to register another airline after inital 4 are registered");
  });

});
