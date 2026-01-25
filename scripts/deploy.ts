import { deployProtocol } from '../src/deploy'
import { formatIgnitionDeployments } from '../src/format'

const main = async () =>
  await deployProtocol().then(() => formatIgnitionDeployments())

main()
