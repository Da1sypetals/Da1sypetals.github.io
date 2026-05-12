#import "/config.typ": template, tufted
#show: template.with(
  // title: "用音频修复的方式解决音高微调问题",
  title: "Addressing Pitch Fine-Tuning Challenges Through Audio Restoration",
  date: datetime(year: 2026, month: 5, day: 10),
  lang: "en",
)


== Background

Research on vocal performance differs significantly from other forms of art. The consumption of vocal music is human-centered: consumers tend to associate a vocal performance with a particular artist, rather than treating each song as an independent piece. This stands in stark contrast to the consumption of visual art design or instrumental music.

Additionally, the following observations are relevant:

- Fine pitch shift remains an important problem in vocal music production, as companies that make this kind of software continue to be profitable. As far as I know, deep learning is not the core of their proprietary algorithms.

- Typical pitch shifts are within a small range (say, $plus.minus 200 "cents"$). If your singing deviates from the expected pitch too much, you may need to practice singing instead of looking for software to tune it.

Based on these observations, I conclude that fine control is more important than end-to-end systems in the refinement of vocal performance. Therefore, even though the whole industry is focused on end-to-end models, a system that allows fine control over the pitch of each note remains valuable.

== Design

=== Data

Given the copyright nature of production-level music, it is extremely difficult to find high quality vocal stem, and there is basically no source of paired (before pitch shift, after pitch shift) data. Given this challenge, modeling this problem as supervised lerning is unrealistic, and we are forced to come up with a self-supervised (or unsupervised) approach.

==== DSP algorithms come to our rescue

Existing non-DL#footnote[Deep Learning] DSP algorithms, such as phase vocoders, WORLD@world, and time-domain pitch shifters (e.g., Rubberband), provide formant-preserving ways to shift pitch. They work reasonably well when artificial timbre changes are expected or even desired. However, for my vocal fine-tuning scenario, these methods inevitably introduce audible artifacts, like metallic ringing, phasiness, and unnatural formant smearing.

But this distortion is not chaotic; it follows a fixed, algorithm-dependent transform. The key observation is that the shifted audio from a traditional DSP algorithm can be treated as a distorted version of a hypothetical “cleanly restored” audio. This gives us a self-supervised path: we can deliberately create such distorted audio by chaining two opposite pitch shifts (with the same DSP engine) and then train a neural network to revert the distortion, effectively learning to restore the original quality without requiring paired before/after data.



=== Modeling

// todo: a sentence or two to lead to the flowchart.

The diagram below illustrates how the system works during training.

#figure(image("flowchart.png"), caption: "Flow chart of the modeling method")

// ```mermaid
// flowchart LR
//     %% Top row
//     RA([Restored Audio])
//     NN[NN]

//     %% Middle row
//     IA([Input Audio])
//     RB1["Rubberband<br/>(pitch shift)"]
//     SA([Shifted audio])
//     RB2["Rubberband<br/>(pitch shift)"]
//     DA([Distorted Audio])

//     %% Bottom row
//     PE(["Pitch Envelope<br/>(keyframes +<br/>lerp between frames)"])
//     NEG["-"]
//     INV([Inverted Pitch Envelope])

//     %% Main flow
//     IA --> RB1 --> SA --> RB2 --> DA

//     %% Loss connection
//     RA <-->|Loss| IA

//     %% Pitch envelope routing
//     PE --> RB1
//     PE --> NEG --> INV
//     INV --> RB2

//     %% Neural network restoration
//     DA --> NN --> RA

//     %% Styles
//     classDef input fill:#efe3b0,stroke:#d4a000,stroke-width:2px,color:#000;
//     classDef middle fill:#f3dfc7,stroke:#d89b00,stroke-width:2px,color:#000;
//     classDef green fill:#cdddc9,stroke:#6aa84f,stroke-width:2px,color:#000;
//     classDef red fill:#e9c7c7,stroke:#c0504d,stroke-width:2px,color:#000;

//     class IA,PE input;
//     class RA,SA,DA,INV middle;
//     class RB1,RB2,NEG green;
//     class NN red;
// ```



=== V1

This version produces reasonable results, but still has some problem, e.g. $f_0$ jitter.

==== Representation and Loss

I studied this part intensely, but the final solution was a compromising one.

The desired representation should exhibit:

+ Bidirectionally-covertible between the representation and high-quality waveform, preferablly mathematically invertible
+ Deep-Learning friendly, pattern is easy for neural network to learn

STFT exhibits property 1, Mel-Spectrogram exhibits property 2. But after a few rounds of experiments, either caused by insufficient data or the inherent properties of STFT, performance of NN learning on Mel-spectrogram outperform STFT massively.

*For now* Mel-spectrogram is used, but I am still very interested in designing audio representation that has good enough theoretical properties, and will keep investigating.

==== Network

This part is very random currently. I just told LLMs to analyze the potential parameter count the model need to perform the task well, then have it design a random Temporal U-Net for me.


- Vocoder: NSF-HiFiGAN
- Input conditioning:
  - $f_0$ curve
  - Per-frame #link("https://github.com/openvpi/SingingVocoders", "ContentVec")@qian2022contentvecimprovedselfsupervisedspeech


==== Optimizer

Muon@jordan2024muon optimizer is used in parameters with ndim $>= 2$, and AdamW@adamw is used for the rest. As Su suggests @kexuefm-11416, Muon's update RMS is matched against AdamW's, and parameters of convolution layers are reshaped to allow $"msign"$ to operate on it.


==== Others

*Important*: Make sure don't seed NumPy and PyTorch manually each epoch. We don't care about reproducibility, just let system seed for us.


=== V1.5

Use Rubberband for pitch shift, U-Net for restoration. Rubberband (with formant preserving option enabled) has better quality than WORLD, so the system produces better results.

=== V1.6

Enhanced data preparation and loss weights:

Transition segments (whose $f_0$ is not consistent in a small time window) produces more intense aritfacts, I give transition frames $16 times$ loss weight.

Plot of input/output loudness distribution shows that loudness consistency is learned, but difference $>3 "db"$ is still observed. Therefore auxiliary loss to penalize loudness difference with weight $lambda_"loudness"=1/16$ is added as an attempt to alleviate this probelm.

#figure(image("loudness.png"))

=== V1.7

Previous versions merges conditions (ContentVec, $f_0$, volume) by adding, which is used by Diff-SVC@diffsvc. V1.7 switch to channel concatenation. There is no good reason; it's simply because I think addition is a bad idea to mix features.

We have GT $f_0$ at inference (original $f_0$ curve shifted by factor $2^("cents"/100)$), so the $f_0$ input to the network (U-Net, Vocoder) does not need to come from $f_0$ estimation of the artifact audio; instead we can directly use the $f_0$ estimation of the clean audio.

==== Speeding Up Training

I (actually LLM) rewrite Rubberband in Rust (because it's not suitable for GPU) and added batched & parallel processing with Rayon. Used together with data/GPU pipelining, average step time drop from 40s to 18s, which is very close to the raw rubberband process time for each step (6144 samples).

=== TODO: iterating more versions

== Demo Product

The demo is an application on macOS implemented with #link("https://github.com/emilk/egui/", "egui"). Inference is implemented with mlx@mlx, and Metal compute shaders are implemented for operations unsupported in mlx.


#bibliography("refs.bib")
