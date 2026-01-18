const fs = require('fs')
const path = require('path')

const sanitizeMDX = str =>
  str.replace('{', '\\{').replace('}', '\\}').replace('!', '\\!')

const constructorTemplate = (property, contract) =>
  `\`\`\`solidity
constructor(${
    property?.inputs
      .map(
        argument =>
          `${argument.name}: ${argument.type} ${
            argument.indexed === false ? 'not ' : ''
          }indexed`
      )
      .join(', ') ?? ''
  }): ${contract.name}
\`\`\`
`

const eventTemplate = (property, contract) =>
  `- #### ++dnt++${contract.name}.${property.name}

\`\`\`solidity
event ${property.name}(${property.inputs
    .map(
      argument =>
        `${argument.name}: ${argument.type} ${
          argument.indexed === false ? 'not ' : ''
        }indexed`
    )
    .join(', ')})
\`\`\`
`

const methodTemplate = (_function, contract) =>
  `- #### ++dnt++${contract.name}.${_function.name}
  ${
    _function.inputs.length > 0
      ? ` - Parameters:${_function.inputs
          .map(
            argument =>
              `
                 - \`${argument.name}\`: \`${argument.type} ${
                argument.indexed === false ? 'not ' : ''
              }indexed\`${
                argument.details
                  ? `
                 - COUCOU ${argument.details}`
                  : ''
              }`
          )
          .join('')}
  `
      : ''
  }${
    _function.outputs.length > 0
      ? `  - Returns: ++dnt++${_function.outputs
          .map(
            argument =>
              `${argument.type} ${
                argument.indexed === false ? 'not ' : ''
              }indexed
`
          )
          .join(', ')}`
      : ''
  }${
    _function.notice != null && _function.notice !== ''
      ? `
  ${_function.notice.replace(':warning: **Warning** :warning:', '⚠️')}`
      : ''
  }${
    _function.details != null && _function.details !== ''
      ? `
> ${sanitizeMDX(_function.details)}
  `
      : ''
  }

\`\`\`solidity
${_function.name}(${_function.inputs
    .map(
      argument =>
        `${argument.name}: ${argument.type} ${
          argument.indexed === false ? 'not ' : ''
        }indexed`
    )
    .join(', ')}): ${
    _function.outputs.length > 0
      ? _function.outputs
          .map(
            argument =>
              `${argument.type} ${
                argument.indexed === false ? 'not ' : ''
              }indexed`
          )
          .join(', ')
      : 'void'
  }
\`\`\`
`

const contractTemplate = contract => {
  const title = `## ++dnt++contract ${contract.name}`
  const description = contract.devdoc?.details
    ? `> ${sanitizeMDX(contract.devdoc?.details)}`
    : ''
  const notice = contract.userdoc?.notice
    ? `> ${contract.userdoc.notice.replace(
        ':warning: **Warning** :warning:',
        '⚠️'
      )}`
    : ''
  const constructor = contract.abiDocs.find(item => item.type === 'constructor')
  const events = contract.abiDocs.filter(item => item.type === 'event')
  const functions = contract.abiDocs.filter(item => item.type === 'function')
  return `${title}

${description}

${notice}

${constructorTemplate(constructor, contract)}

### ++dnt++Events - ${contract.name}:
${events.map(event => eventTemplate(event, contract)).join('')}

### ++dnt++Methods - ${contract.name}:
${functions
  .filter(
    _function =>
      !(_function.name === 'initialize' && _function.inputs[0]?.name === '')
  )
  .map(func => methodTemplate(func, contract))
  .join('')}
`
}

function formatABI (method, contract) {
  const inputParams = method.inputs ?? []
  const signature =
    method.name && `${method.name}(${inputParams.map(i => i.type).join(',')})`
  const devDocs = (contract.devdoc?.methods ?? {})[signature] ?? {}
  const userDocs = (contract.userdoc?.methods ?? {})[signature] ?? {}
  // map abi inputs to devdoc inputs
  const params = devDocs.params ?? {}
  const inputs = inputParams.map(param => ({
    ...param,
    description: params[param.name]
  }))
  const argumentList = inputParams
    .reduce((inputString, param) => `${inputString}${param.name}, `, '')
    .slice(0, -2)
  // don't write this
  // delete devDocs.params

  const outputs = parseOutputs({ devDocs, method })

  return {
    ...method,
    ...devDocs,
    ...userDocs,
    inputs,
    argumentList,
    outputs,
    signature
    // signatureHash: signature && getFunctionSignature(signature),
  }
}

function parseOutputs ({ devDocs, method }) {
  let outputs = []
  try {
    if (typeof devDocs.returns !== 'undefined') {
      const outputParams = devDocs.returns
      outputs = method.outputs.map(param => ({
        ...param,
        description: outputParams[param.name]
      }))
    }
  } catch (e) {
    process.stderr.write(
      `warning: invalid @return for ${method.name} - output may be effected\n
      ${e.message}
      `
    )
    outputs = method.outputs // eslint-disable-line prefer-destructuring
  }

  return outputs
}

function markdown ({ data }) {
  return new Promise((resolve, reject) => {
    // write to dest stream
    let writeStream
    try {
      writeStream = fs.createWriteStream(
        `../../stack/assets/docs/reference/${
          data != null ? 'solidity' : 'js'
        }.mdx`,
        { flags: 'w' }
      )
    } catch (err) {
      reject(err)
    }
    writeStream.on('error', err => {
      reject(err)
    })
    writeStream.on('finish', () => {
      resolve()
    })
    writeStream.write(`
export const metadata = { title: "⛓ Solidity", order: 6.1 }

# Solidity reference ⛓

The official Solidity documentation for the contracts and types used in the ${
      process.env.NEXT_PUBLIC_COMPANY_URL
    } stack.

## @organigram/protocol

Solidity smart contracts for the [Organigram protocol](/docs/protocol).

### Install

\`\`\`bash
pnpm add @organigram/protocol
\`\`\`

### Init

Deploying an ${process.env.NEXT_PUBLIC_COMPANY_URL} instance with Truffle:

\`\`\`javascript init.js
// from ../../code-examples/initContracts.js
\`\`\`


### Contracts

${data
  ?.map?.(
    contract =>
      `- [${contract.name}](/docs/reference/solidity#contract_${contract.name})`
  )
  ?.join('\n')}

`)
    if (data !== undefined && data.length !== 0) {
      // create docs for each contract from template
      data?.forEach?.(contract => {
        const md = contractTemplate(contract)
        writeStream.write(md)
      })
    }
    writeStream.end()
  })
}

function compile ({ contracts }) {
  const data = []
  Object.keys(contracts).forEach(contractName => {
    const contract = contracts[contractName]
    data.push({
      ...contract,
      title: contract.devdoc?.title,
      name: contractName,
      abiDocs: contract.abi.map(abi => formatABI(abi, contract))
    })
  })

  return data.filter(d => d.abiDocs.length > 0)
}

const walkPath = dir => {
  let results = []
  const list = fs.readdirSync(dir)
  list.forEach(function (file) {
    const filePath = path.join(dir, file)
    const stat = fs.statSync(filePath)
    if (stat?.isDirectory()) {
      results = results.concat(walkPath(filePath))
    } else {
      results.push(filePath)
    }
  })

  return results
}

function build () {
  const files = walkPath('./build/contracts')
  const contracts = files.reduce((acc, file) => {
    const contract = JSON.parse(fs.readFileSync(file, 'utf8'))
    const { contractName, sourcePath } = contract
    if (
      sourcePath.slice(0, 1) !== '@' &&
      !contractName.includes('Example') &&
      !contractName.includes('Migrations') &&
      !contractName.includes('MetaGasStation')
    ) { acc[contractName] = contract }
    return acc
  }, {})
  const data = compile({ contracts })
    .sort(a => (a.name === 'VoteProcedure' ? -1 : 1))
    .sort(a => (a.name === 'ERC20VoteProcedure' ? -1 : 1))
    .sort(a => (a.name === 'NominationProcedure' ? -1 : 1))
    .sort(a => (a.name === 'Procedure' ? -1 : 1))
    .sort(a => (a.name === 'Organ' ? -1 : 1))
    .sort(a => (a.name === 'Organigram' ? -1 : 1))
  markdown({ data })
  console.info('done!')
}

build()
