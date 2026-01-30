import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import OrganLibrary from './OrganLibrary'
import crypto from 'crypto'

const OrganigramClientModule = buildModule('OrganigramClientModule', m => {
  const { organLibrary } = m.useModule(OrganLibrary)
  const metaGasStationAddress = m.getParameter(
    'metaGasStationAddress',
    '0x0000000000000000000000000000000000000000' // Default value if not provided
  )
  const proceduresRegistrySalt = '0x' + crypto.randomBytes(32).toString('hex')

  const organigramClient = m.contract(
    'OrganigramClient',
    ['', metaGasStationAddress, proceduresRegistrySalt],
    {
      libraries: {
        OrganLibrary: organLibrary
      }
    }
  )

  return { organigramClient }
})

export default OrganigramClientModule
