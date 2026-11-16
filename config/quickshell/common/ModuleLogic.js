.pragma library

function entries(registry, directory) {
  return registry.filter(module => module.enabled && module.autostart).map(module => {
    const path = module.path.startsWith("/") ? module.path : directory + "/" + module.path;
    return {identifier: module.id, entry: path.endsWith(".qml") ? path : path + "/shell.qml"};
  });
}
