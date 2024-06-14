import React from 'react';
import './App.css';

import Customer from './components/Customer';
import Driver from './components/Driver';

function App() {
  return (
    <div className="App">
      <Customer username="luciano"/>
      {/* <Customer username="dex"/> */}
      <Driver username="jejejeje"/>
      <Driver username="alekong"/>
      <Driver username="alonse"/>
    </div>
  );
}

export default App;
