import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import OrganLibrary from './OrganLibrary'

const OrganigramClientModule = buildModule('OrganigramClientModule', m => {
  const { organLibrary } = m.useModule(OrganLibrary)
  const metaGasStationAddress = m.getParameter(
    'metaGasStationAddress',
    '0x0000000000000000000000000000000000000000' // Default value if not provided
  )

  const organigramClient = m.contract(
    'OrganigramClient',
    ['', metaGasStationAddress],
    {
      libraries: {
        OrganLibrary: organLibrary
      }
    }
  )

  return { organigramClient }
})

export default OrganigramClientModule
