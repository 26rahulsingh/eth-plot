import React, { Component, PropTypes } from 'react';
import { Button, ControlLabel, DropdownButton, MenuItem, FormControl, FormGroup, Label, InputGroup, Modal, PageHeader, Row, Col, Glyphicon, Image, HelpBlock, Checkbox } from 'react-bootstrap';
import Decimal from 'decimal.js';

import ChooseImageInputBox from './PurchaseDialog/ChooseImageInputBox';
import WebsiteInputBox from './PurchaseDialog/WebsiteInputBox';
import BuyoutPriceInputBox from './PurchaseDialog/BuyoutPriceInputBox';

export default class PlotPurchaseForm extends Component {
  constructor(...args) {
    super(...args);

    this.state = {
    }
  }

  computeInitialBuyout() {
    const purchasePrice = Decimal(this.props.purchasePrice);
    const purchaseMultiplier = 3;
    const newPurchasePriceInWei = purchasePrice.times(purchaseMultiplier);

    // TODO
    return {
      units: 'wei',
      ammountInWei: newPurchasePriceInWei.toFixed()
    };
  }

  render() {
    const initialBuyoutPrice = this.computeInitialBuyout();
    return (
      <div>
        <form>
          <ChooseImageInputBox rectToPurchase={this.props.rectToPurchase} />
          <WebsiteInputBox />
          <BuyoutPriceInputBox
            initialValue={initialBuyoutPrice}
            title='Set Initial Buyout Price (Optional)'
            rectToPurchase={this.props.rectToPurchase}
            purchasePrice={this.props.purchasePrice} />
        </form>
      </div>);
  }
}

PlotPurchaseForm.propTypes = {
  rectToPurchase: PropTypes.object.isRequired,
  purchasePrice: PropTypes.string.isRequired // Should be a serialized Decimal.js of wei
}
