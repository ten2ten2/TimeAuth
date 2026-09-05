import { AppRoot } from '../app/AppRoot';

@Entry
@Component
struct Index {
  build() {
    Column() {
      AppRoot()
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
