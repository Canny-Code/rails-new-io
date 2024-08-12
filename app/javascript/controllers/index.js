import { registerControllers } from 'stimulus-vite-helpers'
import { application } from './application'

const controllers = {
  ...importControllers(import.meta.glob(
    './**/*_controller.js',
    { eager: true }
  )),
  ...importControllers(import.meta.glob(
    '../../views/components/**/*_controller.js',
    { eager: true }
  ))
}

function importControllers(controllerModules) {
  return Object.entries(controllerModules).reduce((acc, [path, module]) => {
    const normalizedPath = path
      .replace(/^(\.\/|\.\.\/\.\.\/views\/components\/)/, '')
      .replace(/\//g, '_');
    acc[normalizedPath] = module.default;
    return acc;
  }, {});
}

registerControllers(application, controllers)
