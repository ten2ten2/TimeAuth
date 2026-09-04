@Component
export struct BrandMark {
  @Prop size: number = 42;

  build() {
    Image($r('app.media.brand_logo'))
      .width(this.size)
      .height(this.size)
      .objectFit(ImageFit.Contain)
      .accessibilityText($r('app.string.brand_name'))
  }
}
