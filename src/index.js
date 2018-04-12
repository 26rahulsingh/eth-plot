import * as React from 'react';
import * as ReactDOM from 'react-dom';
/**
 * Import the stylesheet you want used! Here we just reference
 * the main SCSS file we have in the styles directory.
 */
import './styles/main.scss';
/**
 * Both configureStore and Root are required conditionally.
 * See configureStore.js and Root.js for more details.
 */
import { configureStore } from './store/configureStore';
import Root from './containers/Root';
var store = configureStore();
ReactDOM.render(React.createElement(Root, { store: store }), document.getElementById('root'));
//# sourceMappingURL=index.js.map