import { AppRoot } from '../app/AppRoot';

@Entry
@Component
struct Index {
  build() {
    AppRoot()
      .width('100%')
      .height('100%')
  }
}
