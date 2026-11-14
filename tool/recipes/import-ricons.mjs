// Render the published pure SVG components, without a browser or product state.
// The Python generator validates every SVG node and the responsive mark CSS.
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const require = createRequire(`${process.argv[2]}/packages/web/package.json`);
const React = require('react');
const {renderToStaticMarkup} = require('react-dom/server');
const icons = await import(pathToFileURL(require.resolve('@botiverse/ricons')).href);
process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(icons).map(([name, component]) =>
  [name, renderToStaticMarkup(React.createElement(component))]))));
