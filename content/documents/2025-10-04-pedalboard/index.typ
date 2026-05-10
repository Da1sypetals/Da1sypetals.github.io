#import "/config.typ": template, tufted
#show: template.with(
  title: "Pedalboard 文档",
  description: "Spotify Pedalboard API 文档摘录",
  date: datetime(year: 2025, month: 10, day: 4),
)

= Pedalboard 文档

Github: #link("https://github.com/spotify/pedalboard")

Docs: #link("https://spotify.github.io/pedalboard/reference/pedalboard.html")

== Pedalboard API

The `pedalboard` module provides classes and functions for adding effects to audio.

```python
from pedalboard import Pedalboard, Chorus, Distortion, Reverb

my_pedalboard = Pedalboard()
my_pedalboard.append(Chorus())
my_pedalboard.append(Distortion())
my_pedalboard.append(Reverb())

output_audio = my_pedalboard(input_audio, input_audio_samplerate)
```

== Classes

=== AudioProcessorParameter

A wrapper around various different parameters exposed by VST3Plugin or AudioUnitPlugin instances.

=== ExternalPlugin

A wrapper around a third-party effect plugin.

=== Pedalboard(plugins: Optional[List[Plugin]] = None)

A container for a series of `Plugin` objects.

=== load_plugin(path_to_plugin_file: str)

Load an audio plugin.

Two plugin formats are supported:
- VST3 format on macOS, Windows, and Linux
- Audio Units on macOS

== Functions

=== time_stretch

```python
def time_stretch(
    input_audio: numpy.ndarray[numpy.float32],
    samplerate: float,
    stretch_factor: Union[float, numpy.ndarray[numpy.float64]] = 1.0,
    pitch_shift_in_semitones: Union[float, numpy.ndarray[numpy.float64]] = 0.0,
    high_quality: bool = True,
    transient_mode: str = "crisp",
    transient_detector: str = "compound",
    retain_phase_continuity: bool = True,
    use_long_fft_window: Optional[bool] = None,
    use_time_domain_smoothing: bool = False,
    preserve_formants: bool = True,
) -> numpy.ndarray[numpy.float32]
```

Time-stretch (and optionally pitch-shift) a buffer of audio, changing its length.
