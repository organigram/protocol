import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import OrganLibrary from './OrganLibrary'

const OrganigramClientModule = buildModule('OrganigramClientModule', m => {
  const { organLibrary } = m.useModule(OrganLibrary)
  const organigramClient = m.contract(
    'OrganigramClient',
    ['', '0x0000000000000000000000000000000000000000'],
    {
      libraries: {
        OrganLibrary: organLibrary
      }
    }
  )

  return { organigramClient }
})

export default OrganigramClientModule
