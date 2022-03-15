var fs = require('fs');
var networks = require('../networks');
var devilsWheelJSON = JSON.parse(
  fs.readFileSync('./build/contracts/DevilsWheel.json', 'utf8'),
);

if (!fs.existsSync('dist')) fs.mkdirSync('dist');
fs.writeFileSync(
  './dist/index.js',
  `
  module.exports = {
    'abi': ${JSON.stringify(devilsWheelJSON.abi)},
    'compiler': ${JSON.stringify(devilsWheelJSON.compiler)},
    'networks': ${JSON.stringify(networks)},
  };
`,
);
