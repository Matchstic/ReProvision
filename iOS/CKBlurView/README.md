# CKBlurView

This `UIView` subclass demonstrates how Apple does realtime blurring in iOS 7. This class uses **private APIs** and thus should **not be used in production**.

Here is how it works:

- The view is backed by a `CABackdropLayer`, which takes its contents from the layers behind it. This class is new to iOS 7.
- A Gaussian blur [`CAFilter`](http://iphonedevwiki.net/index.php/CAFilter) is applied to the view's layer. This filter has existed since *iOS 3*. The only recent addition is the ability to degrade the quality of the blur (scale down the layer content before blurring), to increase performance.
- This implementation is very minimal, so it does not include additional color filters as Apple's implementation does.

## License

CKBlurView is available under the MIT license. See the LICENSE file for more info.
