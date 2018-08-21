# VIWaveformView

Generate waveform view from audio data.

![](https://ws1.sinaimg.cn/large/6ca4705bgy1fuh2ehbtc7j20ku06xgmb.jpg)

**Code**

```Swift
let waveformView = VIWaveformView()
waveformView.minWidth = UIScreen.main.bounds.width

// Configure wave node view
waveformView.waveformNodeViewProvider = BasicWaveFormNodeProvider(generator: VIWaveformNodeView())

// Load data
let url = Bundle.main.url(forResource: "Moon River", withExtension: "mp3")!
let asset = AVAsset.init(url: url)
_ = waveformView.loadVoice(from: asset, completion: { (asset) in
    // Load complete
})
```