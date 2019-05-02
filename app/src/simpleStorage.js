import React from "react";

class SimpleStorage extends React.Component {
	state = { dataKey: null };

	handleKeyDown = e => {
		// if the enter key is pressed, set the value with the string
		if (e.keyCode === 13) {
			this.setValue(e.target.value);
		}
	};

	setValue = value => {
		const { drizzle, drizzleState } = this.props;
		const contract = drizzle.contracts.SimpleStorage;

		// let drizzle know we want to call the `set` method with `value`
		const stackId = contract.methods.set.cacheSend(value, {
			from: drizzleState.accounts[0]
		});

		// save the `stackId` for later reference
		this.setState({ stackId });
	};

	getTxStatus = () => {
		// get the transaction states from the drizzle state
		const { transactions, transactionStack } = this.props.drizzleState;

		// get the transaction hash using our saved `stackId`
		const txHash = transactionStack[this.state.stackId];

		// if transaction hash does not exist, don't display anything
		if (!txHash) return null;

		// otherwise, return the transaction status
		return `Transaction status: ${transactions[txHash] &&
			transactions[txHash].status}`;
	};

	componentDidMount() {
		const { drizzle, drizzleState } = this.props;
		const contract = drizzle.contracts.SimpleStorage;

		// console.log(drizzle);
		// console.log(drizzleState);
		// console.log(contract);

		// let drizzle know we want to watch the `storedData` method
		const dataKey = contract.methods.storedData.cacheCall();
		// console.log(dataKey);
		// save the `dataKey` to local component state for later reference
		this.setState({ dataKey });
	}

	render() {
		// get the contract state from drizzleState
		//console.log(this.state);
		const { SimpleStorage } = this.props.drizzleState.contracts;

		// using the saved `dataKey`, get the variable we're interested in
		const storedData = SimpleStorage.storedData[this.state.dataKey];

		return (
			<div>
				<input type="text" onKeyDown={this.handleKeyDown} />
				<div>{this.getTxStatus()}</div>
				<p>My stored data: {storedData && storedData.value}</p>
			</div>
		);
	}
}

export default SimpleStorage;
