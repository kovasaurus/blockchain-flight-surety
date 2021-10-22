
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

let gas = 6721975;

(async() => {

    let result = null;

    let FLIGHT_TIMESTAMPS = {
        A1111: 1633963343,
        B2222: 1633943343,
        C3333: 1633993343,
        D4444: 1634193343,
        E5555: 1634293343,
    }  

    let STATUS_CODES = {
        0: "STATUS_CODE_UNKNOWN",
        10: "STATUS_CODE_ON_TIME",
        20: "STATUS_CODE_LATE_AIRLINE",
        30: "STATUS_CODE_LATE_WEATHER",
        40: "STATUS_CODE_LATE_TECHNICAL",
        50: "STATUS_CODE_LATE_OTHER"
    }

    let contract = new Contract('localhost', async () => {

        document.addEventListener("OracleReportEvent", function(e) {
            let flightStatus = STATUS_CODES[e.detail]
            smallerDisplay([{ label: 'Oracle Report Event', value: flightStatus}]);
        })

        document.addEventListener("FlgihtStatusInfo", function(e) {
            let flightStatus = STATUS_CODES[e.detail]
            smallerDisplay([{ label: 'Final flight status', value: flgihtStatus}]);
        })


        // Read transaction
        try {
            const result = await contract.isOperational();
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', value: 'true'} ]);       
        } catch (e) {
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', value: 'false'} ]);       
        }


        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', async () => {
            let flight = DOM.elid('flights-oracle').value;
            let timestamp = FLIGHT_TIMESTAMPS[flight];
            // Write transaction
            await contract.fetchFlightStatus(flight, timestamp);
            display('Submit oracle', 'Submiting request for flight status', [ { label: 'Oracle request', value: 'sent'}]);
        })

        DOM.elid('buy-insurance').addEventListener('click', async () => {
            let flight = DOM.elid('flights-insurance').value;
            let insuranceAmount = DOM.elid('insurance-value').value;
            const result = await contract.buyInsurance(flight, insuranceAmount);
            if (result.status) {
                display('Passanger', 'Buy Insurance', [ { label: 'Transaction passed', value: result.transactionHash}])
            } else {
                display('Passanger', 'Buy Insurance', [ { label: 'Transaction failed', value: result}])
            }
        })
    });


})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}

function smallerDisplay(results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    results.map((result) => {
        let row = section.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-sm-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
}





