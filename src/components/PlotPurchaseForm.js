import React, { Component, PropTypes } from 'react';
import { Button, ControlLabel, DropdownButton, MenuItem, FormControl, FormGroup, Label, InputGroup, Modal, PageHeader, Row, Col, Glyphicon, Image, HelpBlock } from 'react-bootstrap';
import Decimal from 'decimal.js';


const allowedFileTypes = [
  'image/jpeg',
  'image/jpeg',
  'image/png',
  'image/svg+xml'
];

export default class PlotPurchaseForm extends Component {
  constructor(...args) {
    super(...args);

    this.state = {
      fileToUse: null,
      imageFileInfo: null,
      fileValidation: this.validateImageFile(null, null),

      website: '',
      websiteValidation: this.validateWebsite(null),

      buyout: this.computeInitialBuyout(this.props.rectToPurchase),
      buyoutValidation: this.validateBuyout(null)
    }
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevState.fileToUse != this.state.fileToUse || prevState.imageFileInfo != this.state.imageFileInfo) {
      const fileValidation = this.validateImageFile(this.state.fileToUse, this.state.imageFileInfo);
      this.setState({fileValidation: fileValidation});
    }
  }

  browseForImage() {
    this.fileSelectInput.click();
  }

  onFileSelected(event) {
    let newFileToUse = null;

    const files = event.target.files;
    if (files.length === 1) {
      const chosenFile = files[0];
      const fileSize = chosenFile.size;
      const fileName = chosenFile.name;
      const fileType = chosenFile.type;
      const lastModified = chosenFile.lastModified;

      newFileToUse = {
        fileSize: chosenFile.size,
        fileName: chosenFile.name,
        fileType: chosenFile.type,
        lastModified: chosenFile.lastModified
      };

      // Read this file and get some info about it
      this.getImageFileInfoAsync(chosenFile).then(imageFileInfo => {
        this.setState({
          imageFileInfo: imageFileInfo
        });
      });
    }

    this.setState({fileToUse: newFileToUse});
  }

  validateImageFile(file, imageFileInfo) {
    if (!file) {
      return {
        state: null,
        message: 'This is the file which will be in your plot'
      };
    }

    if (allowedFileTypes.indexOf(file.fileType) < 0) {
      // Not allowed file
      return {
        state: 'error',
        message: 'File must be an image type'
      };
    }

    if (file.fileSize > 3000000) {
      const fileSizeInMb = file.fileSize / 1000000;
      return {
        state: 'error',
        message: `File must be less than 3MB (file is ${fileSizeInMb}MB)`
      };
    }

    if (imageFileInfo) {
      const aspectRatio = imageFileInfo.w / imageFileInfo.h;
      const targetRatio = this.props.rectToPurchase.w / this.props.rectToPurchase.h;
      if (Math.abs(aspectRatio - targetRatio) > 0.01) {
        return {
          state: 'warning',
          message: `Selected image does not match the aspect ratio of the target`
        };
      }
    } else {
      return {
        state: 'warning',
        message: 'Processing selected image...'
      };
    }

    return {
      state: 'success',
      message: 'The image looks great!'
    };
  }

  getImageFileInfoAsync(file) {
    return new Promise((resolve, reject) => {
      const fileReader = new FileReader;
      fileReader.onload = function() {
        this.imagePreview.onload = function () {
          const imageFileInfo = {
            w: this.imagePreview.width,
            h: this.imagePreview.height,
            fileName: file.name,
            fileData: fileReader.result
          };

          resolve(imageFileInfo);
        }.bind(this);

        this.imagePreview.src = fileReader.result;
      }.bind(this);
      
      fileReader.readAsDataURL(file);
    });
  }

  websiteChanged(event) {
    const newValue = event.target.value;
    const validation = this.validateWebsite(newValue);
    this.setState({
      website: newValue,
      websiteValidation: validation
    });
  }

  validateWebsite(website) {
    if (!website || website.length == 0) {
      return {
        state: null,
        message: 'The website where your plot links to'
      };
    }

    if (website.length < 7) {
      return {
        state: 'error',
        message: 'The website must be at least 7 characters'
      };
    }

    if (website.indexOf('http://') !== 0 && website.indexOf('https://') !== 0) {
      return {
        state: 'error',
        message: `The website must start with 'http://' or 'https://'`
      };
    }

    if (website.length > 2048) {
      return {
        state: 'error',
        message: `The website must be less than 2048 characters (${website.length} characters)`
      };
    }

    return {
      state: 'success',
      message: `Users will go to ${website} when clicking your plot`
    };
  }

  buyoutPriceChanged(event) {
    const units = this.state.buyout.units;
    const mulitplier = units == 'wei' ? 0 : units == 'gwei' ? 9 : 18;
    const newPriceInWei = Decimal(event.target.value + `e${mulitplier}`);
    this.setState({
      buyout: {
        units: units,
        ammountInWei: newPriceInWei.toFixed()
      }
    });
  }

  buyoutUnitChanged(eventKey, event) {
    const buyoutUnits = eventKey;

    this.setState({
      buyout: {
        units: buyoutUnits,
        ammountInWei: this.state.buyout.ammountInWei
      }
    });
  }

  computeInitialBuyout(rectToPurchase) {
    // TODO
    return {
      units: 'wei',
      ammountInWei: '492'
    };
  }

  validateBuyout(buyout) {
    if (!buyout) {
      return {
        state: null,
        message: 'The price you will receive if your full plot is purchased'
      }
    }
  }

  render() {
    const imageLabel = `Plot Image (${this.props.rectToPurchase.w} x ${this.props.rectToPurchase.h})`;
    const buyoutMultiplier = this.state.buyout.units == 'eth' ? -18 : this.state.buyout.units == 'gwei' ? -9 : 0;
    const buyoutString = Decimal(this.state.buyout.ammountInWei + `e${buyoutMultiplier}`).toFixed();

    return (
      <div>
        <form>
          <FormGroup controlId='imageSelection' validationState={this.state.fileValidation.state}>
            <ControlLabel>{imageLabel}</ControlLabel>
            <InputGroup>
              <InputGroup.Button>
                <Button onClick={this.browseForImage.bind(this)}>Browse...</Button>
              </InputGroup.Button>
              <FormControl type="text" value={this.state.fileToUse ? this.state.fileToUse.fileName: ''}/>
            </InputGroup>
            <FormControl.Feedback />
            <HelpBlock>{this.state.fileValidation.message}</HelpBlock>
          </FormGroup>

          <FormGroup controleId='websiteEntry' validationState={this.state.websiteValidation.state}>
            <ControlLabel>Website</ControlLabel>
            <FormControl type="url" onChange={this.websiteChanged.bind(this)}/>
            <FormControl.Feedback />
            <HelpBlock>{this.state.websiteValidation.message}</HelpBlock>
          </FormGroup>

          <FormGroup controleId='buyoutPrice' validationState={this.state.buyoutValidation.state}>
            <ControlLabel>Initial Buyout Price</ControlLabel>
            <InputGroup>
            <FormControl value={buyoutString} type="number" onChange={this.buyoutPriceChanged.bind(this)}/>
            <DropdownButton componentClass={InputGroup.Button} id="input-wei" title={this.state.buyout.units} onSelect={this.buyoutUnitChanged.bind(this)} > 
              <MenuItem eventKey="wei">wei</MenuItem>
              <MenuItem eventKey="gwei">gwei</MenuItem>
              <MenuItem eventKey="eth">eth</MenuItem>
            </DropdownButton>
            </InputGroup>
            <HelpBlock>{this.state.buyoutValidation.message}</HelpBlock>
          </FormGroup>
        </form>
        <input accept={allowedFileTypes.join(',')} onChange={this.onFileSelected.bind(this)} type='file' ref={(input) => { this.fileSelectInput = input; }} className='hidden' />
        <img ref={(input) => this.imagePreview = input } className='hidden'/>
      </div>);
  }
}

PlotPurchaseForm.propTypes = {
  rectToPurchase: PropTypes.object.isRequired,
  purchasePrice: PropTypes.object.isRequired // Should be a serialized big number of wei
}
