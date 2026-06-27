import * as fs from 'node:fs'
import * as path from 'node:path'
import { fileURLToPath } from 'node:url'

interface AbiParameter {
  type: string
  name?: string
  indexed?: boolean
  components?: AbiParameter[]
  description?: string
}

interface AbiDocEntry {
  type: string
  name?: string
  title?: string
  notice?: string
  details?: string
  inputs?: AbiParameter[]
  outputs?: AbiParameter[]
  stateMutability?: string
  signature?: string | false
}

interface MethodDocs {
  params?: Record<string, string>
  returns?: Record<string, string>
  notice?: string
  details?: string
}

interface ContractDevdoc {
  title?: string
  details?: string
  methods?: Record<string, MethodDocs>
}

interface ContractUserdoc {
  notice?: string
  methods?: Record<string, Pick<AbiDocEntry, 'notice' | 'details'>>
}

interface CompiledContract {
  name: string
  title?: string
  abi: AbiDocEntry[]
  abiDocs: DocumentedAbiEntry[]
  devdoc?: ContractDevdoc
  userdoc?: ContractUserdoc
}

interface ArtifactJson {
  abi: AbiDocEntry[]
  metadata?: {
    settings?: {
      compilationTarget?: Record<string, string>
    }
    output: {
      devdoc?: ContractDevdoc
      userdoc?: ContractUserdoc
    }
  }
}

interface DocumentedAbiEntry extends AbiDocEntry {
  inputs: AbiParameter[]
  outputs: AbiParameter[]
  signature?: string | false
}

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const DOCS_OUTPUT_PATH = path.resolve(
  __dirname,
  '../../docs/mdx/reference/solidity.mdx'
)

const INCLUDED_CONTRACTS = new Set<string>([
  'OrganigramClient',
  'Organ',
  'Procedure',
  'NominationProcedure',
  'ERC20VoteProcedure',
  'VoteProcedure',
  'IOrgan',
  'OrganLibrary',
  'ProcedureLibrary'
])

const escapeMDX = (value: unknown): string =>
  String(value ?? '')
    .replace(/{/g, '\\{')
    .replace(/}/g, '\\}')
    .trim()

const sanitizeNotice = (value: unknown): string =>
  escapeMDX(value).replace(':warning: **Warning** :warning:', 'Warning:')

const quote = (value: unknown): string =>
  escapeMDX(value)
    .split('\n')
    .filter(Boolean)
    .map(line => `> ${line}`)
    .join('\n')

const canonicalType = (param: AbiParameter): string => {
  if (param.type.startsWith('tuple')) {
    const suffix = param.type.slice('tuple'.length)
    const inner = (param.components ?? []).map(canonicalType).join(', ')
    return `(${inner})${suffix}`
  }
  return param.type
}

const getArgumentName = (argument: AbiParameter, index: number): string =>
  argument.name != null && argument.name !== '' ? argument.name : `arg${index}`

const renderSignatureArguments = (
  argumentsList: AbiParameter[] = [],
  options: { event?: boolean } = {}
): string =>
  argumentsList
    .map((argument, index) => {
      const name = getArgumentName(argument, index)
      const type = canonicalType(argument)
      if (options.event === true) {
        return `${type}${argument.indexed === true ? ' indexed' : ''} ${name}`
      }
      return `${type} ${name}`
    })
    .join(', ')

const renderReturnsSignature = (outputs: AbiParameter[]): string => {
  if (outputs.length === 0) return ''
  return ` returns (${outputs
    .map((argument, index) => {
      const type = canonicalType(argument)
      return argument.name != null && argument.name !== ''
        ? `${type} ${getArgumentName(argument, index)}`
        : type
    })
    .join(', ')})`
}

const renderStateMutability = (method: DocumentedAbiEntry): string => {
  if (
    method.stateMutability == null ||
    ['nonpayable', 'view', 'pure', 'payable'].includes(method.stateMutability) ===
      false
  ) {
    return ''
  }
  return method.stateMutability === 'nonpayable'
    ? ''
    : ` ${method.stateMutability}`
}

const hasDocumentation = (items: AbiParameter[]): boolean =>
  items.some(item => item.description != null && item.description !== '')

const renderItemsTable = (title: string, items: AbiParameter[]): string => {
  if (items.length === 0 || !hasDocumentation(items)) return ''

  const rows = items
    .map((item, index) => {
      const name = `\`${getArgumentName(item, index)}\``
      const type = `\`${canonicalType(item)}\``
      const description =
        item.description != null && item.description !== ''
          ? escapeMDX(item.description)
          : ' '
      return `| ${name} | ${type} | ${description} |`
    })
    .join('\n')

  return `**${title}**

| Name | Type | Description |
| --- | --- | --- |
${rows}
`
}

const renderSignatureBlock = (signature: string): string => `\`\`\`solidity
${signature}
\`\`\``

const renderConstructor = (constructor?: DocumentedAbiEntry): string => {
  if (constructor == null) return ''
  return `### Constructor

${renderSignatureBlock(
  `constructor(${renderSignatureArguments(constructor.inputs)});`
)}
`
}

const renderEvent = (event: DocumentedAbiEntry, contract: CompiledContract): string => {
  const signature = `event ${event.name}(${renderSignatureArguments(event.inputs, {
    event: true
  })});`

  return `#### ++dnt++${contract.name}.${event.name}

${event.notice != null && event.notice !== '' ? `${sanitizeNotice(event.notice)}\n\n` : ''}${
    event.details != null && event.details !== '' ? `${quote(event.details)}\n\n` : ''
  }${renderSignatureBlock(signature)}

${renderItemsTable('Arguments', event.inputs)}
`
}

const renderMethod = (method: DocumentedAbiEntry, contract: CompiledContract): string => {
  const signature = `function ${method.name}(${renderSignatureArguments(
    method.inputs
  )})${renderStateMutability(method)}${renderReturnsSignature(method.outputs)};`

  return `#### ++dnt++${contract.name}.${method.name}

${method.notice != null && method.notice !== '' ? `${sanitizeNotice(method.notice)}\n\n` : ''}${
    method.details != null && method.details !== ''
      ? `${quote(method.details)}\n\n`
      : ''
  }${renderSignatureBlock(signature)}

${renderItemsTable('Parameters', method.inputs)}${
    renderItemsTable('Returns', method.outputs)
  }
`
}

const renderSection = <T>(
  title: string,
  items: T[],
  template: (item: T) => string
): string => {
  if (items.length === 0) return ''
  return `### ${title}

${items.map(template).join('\n')}
`
}

const renderContract = (contract: CompiledContract): string => {
  const title = `## ++dnt++contract ${contract.name}`
  const subtitle =
    contract.title != null && contract.title !== '' && contract.title !== contract.name
      ? `${escapeMDX(contract.title)}\n\n`
      : ''
  const description =
    contract.userdoc?.notice != null && contract.userdoc.notice !== ''
      ? `${sanitizeNotice(contract.userdoc.notice)}\n\n`
      : ''
  const details =
    contract.devdoc?.details != null && contract.devdoc.details !== ''
      ? `${quote(contract.devdoc.details)}\n\n`
      : ''
  const constructor = contract.abiDocs.find(item => item.type === 'constructor')
  const events = contract.abiDocs.filter(item => item.type === 'event')
  const functions = contract.abiDocs
    .filter(item => item.type === 'function')
    .filter(
      item => !(item.name === 'initialize' && item.inputs[0]?.name === '')
    )

  return `${title}

${subtitle}${description}${details}${renderConstructor(
    constructor
  )}${renderSection('Events', events, event => renderEvent(event, contract))}${renderSection(
    'Functions',
    functions,
    method => renderMethod(method, contract)
  )}`
}

function formatABI(
  method: AbiDocEntry,
  contract: { devdoc?: ContractDevdoc; userdoc?: ContractUserdoc }
): DocumentedAbiEntry {
  const inputParams = method.inputs ?? []
  const signature =
    method.name != null
      ? `${method.name}(${inputParams.map(canonicalType).join(',')})`
      : undefined
  const devDocs =
    signature != null ? (contract.devdoc?.methods ?? {})[signature] ?? {} : {}
  const userDocs =
    signature != null ? (contract.userdoc?.methods ?? {})[signature] ?? {} : {}
  const params = devDocs.params ?? {}
  const inputs = inputParams.map((param: AbiParameter) => ({
    ...param,
    description: param.name != null ? params[param.name] : undefined
  }))

  return {
    ...method,
    ...devDocs,
    ...userDocs,
    inputs,
    outputs: parseOutputs({ devDocs, method }),
    signature
  }
}

function parseOutputs({
  devDocs,
  method
}: {
  devDocs: MethodDocs
  method: AbiDocEntry
}): AbiParameter[] {
  let outputs: AbiParameter[] = []
  try {
    if (typeof devDocs.returns !== 'undefined') {
      const outputParams = devDocs.returns
      outputs = (method.outputs ?? []).map((param: AbiParameter) => ({
        ...param,
        description: param.name != null ? outputParams[param.name] : undefined
      }))
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    process.stderr.write(
      `warning: invalid @return for ${method.name} - output may be affected\n${message}\n`
    )
    outputs = method.outputs ?? []
  }

  if (outputs.length === 0) {
    outputs = method.outputs ?? []
  }

  return outputs
}

function compile({
  contracts
}: {
  contracts: Record<string, { devdoc?: ContractDevdoc; userdoc?: ContractUserdoc; abi: AbiDocEntry[] }>
}): CompiledContract[] {
  const data: CompiledContract[] = []
  Object.keys(contracts).forEach(contractName => {
    const contract = contracts[contractName]
    data.push({
      ...contract,
      title: contract.devdoc?.title,
      name: contractName,
      abiDocs: contract.abi.map(abi => formatABI(abi, contract))
    })
  })

  return data.filter(contract => contract.abiDocs.length > 0)
}

const walkPath = (dir: string): string[] => {
  let results: string[] = []
  const list = fs.readdirSync(dir)

  list.forEach(file => {
    const filePath = path.join(dir, file)
    const stat = fs.statSync(filePath)
    if (stat.isDirectory()) {
      results = results.concat(walkPath(filePath))
    } else {
      results.push(filePath)
    }
  })

  return results
}

function markdown({ data }: { data: CompiledContract[] }): Promise<void> {
  return new Promise((resolve, reject) => {
    let writeStream: fs.WriteStream
    try {
      writeStream = fs.createWriteStream(DOCS_OUTPUT_PATH, { flags: 'w' })
    } catch (error) {
      reject(error)
      return
    }

    writeStream.on('error', reject)
    writeStream.on('finish', resolve)

    const companyName =
      process.env.NEXT_PUBLIC_COMPANY_URL ??
      process.env.NEXT_PUBLIC_COMPANY_LEGAL_NAME ??
      'Organigram.ai'

    writeStream.write(`export const metadata = { title: "⛓️ Solidity", order: 5.1 }

# Solidity reference ⛓️

The official Solidity documentation for the contracts and types used in the ${companyName} stack.

## @organigram/protocol

Solidity smart contracts for the [Organigram Protocol](/docs/protocol).

### Install

\`\`\`bash
pnpm add @organigram/protocol
\`\`\`

### Contracts

${data
  .map(contract => `- [${contract.name}](/docs/reference/solidity#contract_${contract.name})`)
  .join('\n')}

`)

    data.forEach(contract => {
      writeStream.write(renderContract(contract))
      writeStream.write('\n\n')
    })

    writeStream.end()
  })
}

const prioritizeName =
  (name: string) =>
  (a: CompiledContract, b: CompiledContract): number =>
    Number(b.name === name) - Number(a.name === name)

function build(): Promise<void> {
  const files = walkPath('./abi')
  const contracts = files.reduce<Record<string, { devdoc?: ContractDevdoc; userdoc?: ContractUserdoc; abi: AbiDocEntry[] }>>((acc, file) => {
    if (!file.endsWith('.json') || file.includes('/build-info/')) return acc

    const contract = JSON.parse(fs.readFileSync(file, 'utf8')) as ArtifactJson
    const compilationTarget = contract?.metadata?.settings?.compilationTarget
    const sourcePath = compilationTarget
      ? Object.keys(compilationTarget)[0]
      : undefined
    const contractName =
      sourcePath != null ? compilationTarget?.[sourcePath] : undefined

    if (
      sourcePath?.startsWith('contracts/') &&
      contractName != null &&
      INCLUDED_CONTRACTS.has(contractName) &&
      !contractName.includes('MetaGasStation')
    ) {
      acc[contractName] = {
        ...(contract.metadata?.output ?? {}),
        abi: contract.abi
      }
    }

    return acc
  }, {})

  const data = compile({ contracts })
    .sort(prioritizeName('VoteProcedure'))
    .sort(prioritizeName('ERC20VoteProcedure'))
    .sort(prioritizeName('NominationProcedure'))
    .sort(prioritizeName('Procedure'))
    .sort(prioritizeName('Organ'))
    .sort(prioritizeName('OrganigramClient'))

  return markdown({ data })
}

build()
  .then(() => {
    console.info('done!')
  })
  .catch(error => {
    console.error(error)
    process.exitCode = 1
  })
