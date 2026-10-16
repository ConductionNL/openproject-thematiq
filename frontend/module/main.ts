// The plugin's Angular module. OpenProject links it into its own frontend build when the image is built with
// the frontend target of docker/Dockerfile (rake openproject:plugins:register_frontend). The default image
// never compiles this file.
import { NgModule } from '@angular/core';
import { markLinked } from './linked-marker';

@NgModule({})
export class PluginModule {
  constructor() {
    markLinked(document);
  }
}
