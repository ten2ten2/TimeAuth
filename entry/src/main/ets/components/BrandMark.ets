@Component
export struct BrandMark {
  @Prop markSize: number = 42;

  build() {
    Image($r('app.media.brand_logo'))
      .width(this.markSize)
      .height(this.markSize)
      .objectFit(ImageFit.Contain)
      .accessibilityText($r('app.string.brand_name'))
  }
}
