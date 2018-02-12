import React, { Component } from 'react';
import PropTypes from 'prop-types';

import { withStyles } from 'material-ui/styles';
import ExpansionPanel, {
  ExpansionPanelSummary,
  ExpansionPanelDetails,
} from 'material-ui/ExpansionPanel';
import Button from 'material-ui/Button';
import Typography from 'material-ui/Typography';
import ExpandMoreIcon from 'material-ui-icons/ExpandMore';
import Grid from 'material-ui/Grid';
import Paper from 'material-ui/Paper';

import BuyoutPriceInputBox from './PurchaseDialog/BuyoutPriceInputBox';

const styles = theme => ({
  root: {
    padding: 16
  },
  button: {
    marginRight: theme.spacing.unit,
  },
});

class PlotInfo extends Component {
  constructor(...args) {
		super(...args);
		this.state = {
      newBuyoutPrice: 0,
      toggleEnabled: false,
      auctionVisible: false
		};
  }
  
  onBuyoutChanged(buyoutChangedMessage) {
    this.setState({newBuyoutPrice: buyoutChangedMessage.value})
  }

  onToggleChanged() {
    this.setState({
      toggleEnabled: !this.state.toggleEnabled,
      auctionVisible: !this.state.auctionVisible,
    });
  }

  updatePrice() {
    this.props.updatePrice(this.props.info.zoneIndex, this.state.newBuyoutPrice);    
  }

  render() {
    const previewStyle = {
      backgroundColor: this.props.info.color,
      width: `${this.props.info.rect.w}px`,
      height: `${this.props.info.rect.w}px`,
    };

    return (
      <Grid className={this.props.classes.root} container spacing={24}>
        <Grid item xs={6} >
        <Typography type='headline'>Plot url: <a href={this.props.info.data.url}>{this.props.info.data.url}</a></Typography>
          
          {
            this.props.info.txHash ?
            <Typography type='headline'>Trasaction in progress: <a href={`https://etherscan.io/address/${this.props.info.txHash}`}>{this.props.info.txHash}</a></Typography>
            : null
          }

          <Typography type='headline'>Buyout price per pixel: {
            (this.props.info.buyoutPrice > 0) ? this.props.info.buyoutPrice : "Not For Sale" }
          </Typography>
          <BuyoutPriceInputBox
            onBuyoutChanged={this.onBuyoutChanged.bind(this)}
            onToggleChanged={this.onToggleChanged.bind(this)}
            rectToPurchase={this.props.info.rect}
            buyoutPriceInWei={this.state.newBuyoutPrice}
            toggleEnabled={this.state.toggleEnabled}
            toggleText={'Edit Buyout'}
            title={'Buyout Price'}
            initialValue={{units: 'wei', ammountInWei: 500}}
            buyoutVisible={this.state.auctionVisible}
          />
          {this.state.toggleEnabled ? (
            <Button className={this.props.classes.button} onClick={this.updatePrice.bind(this)}>Submit</Button>
           ) : null }
        </Grid>
        <Grid item xs={6}>
            { this.props.info.color ? 
              <div style={previewStyle} />
            :
            // TODO update with image support later
            <img src="asdf" />
            }
        </Grid>
      </Grid>
    );
  }
}

PlotInfo.propTypes = {
  info: PropTypes.shape({
    rect: PropTypes.object.isRequired,
    data: PropTypes.object.isRequired,
    zoneIndex: PropTypes.number.isRequired,
  }),
  updatePrice: PropTypes.func.isRequired
};

export default withStyles(styles)(PlotInfo);