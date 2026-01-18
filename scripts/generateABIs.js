const fs = require('fs')

const _in = './build/contracts/'
const _out = './abi/'

if (fs.existsSync(_in)) {
  if (fs.existsSync(_out)) {
    fs.rmdirSync(_out, { recursive: true })
  }
  fs.mkdirSync(_out, 0o744, { recursive: true })

  fs.readdir(_in, (err, files) => {
    if (err) {
      throw err
    }
    files.forEach(file => {
      const contract = JSON.parse(fs.readFileSync(`${_in}${file}`, 'utf8'))
      fs.writeFileSync(`${_out}${file}`, JSON.stringify(contract.abi))
    })
  })

  console.info('ABIs generated in abi/')
}
