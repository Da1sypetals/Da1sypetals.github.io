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

==== The main blocker

Given the copyright nature of production-level music, it is extremely difficult to find high quality vocal stem, and there is basically no source of paired (before pitch shift, after pitch shift) data. Given this challenge, modeling this problem as supervised lerning is unrealistic, and we are forced to come up with a self-supervised (or unsupervised) approach.

==== DSP algorithms come to our rescue

Existing non-DL DSP algorithms, such as phase vocoders, WORLD@world, and time-domain pitch shifters (e.g., Rubberband), provide formant-preserving ways to shift pitch. They work reasonably well for large shifts where artificial timbre changes are expected or even desired. However, for my vocal fine-tuning scenario, these methods inevitably introduce audible artifacts, like metallic ringing, phasiness, and unnatural formant smearing.

But this distortion is not chaotic; it follows a fixed, algorithm-dependent transform. The key observation is that the shifted audio from a traditional DSP algorithm can be treated as a distorted version of a hypothetical “cleanly restored” audio. This gives us a self-supervised path: we can deliberately create such distorted audio by chaining two opposite pitch shifts (with the same DSP engine) and then train a neural network to revert the distortion, effectively learning to restore the original quality without requiring paired before/after data.


==== Input data processing

Artifact is mainly at ... so we ...

=== Modeling

// todo: a sentence or two to lead to the flowchart.

#figure(image("flowchart.png"), caption: "Flow chart of the modeling method")

```mermaid
flowchart LR
    %% Top row
    RA([Restored Audio])
    NN[NN]

    %% Middle row
    IA([Input Audio])
    RB1["Rubberband<br/>(pitch shift)"]
    SA([Shifted audio])
    RB2["Rubberband<br/>(pitch shift)"]
    DA([Distorted Audio])

    %% Bottom row
    PE(["Pitch Envelope<br/>(keyframes +<br/>lerp between frames)"])
    NEG["−"]
    INV([Inverted Pitch Envelope])

    %% Main flow
    IA --> RB1 --> SA --> RB2 --> DA

    %% Loss connection
    RA <-->|Loss| IA

    %% Pitch envelope routing
    PE --> RB1
    PE --> NEG --> INV
    INV --> RB2

    %% Neural network restoration
    DA --> NN --> RA

    %% Styles
    classDef input fill:#efe3b0,stroke:#d4a000,stroke-width:2px,color:#000;
    classDef middle fill:#f3dfc7,stroke:#d89b00,stroke-width:2px,color:#000;
    classDef green fill:#cdddc9,stroke:#6aa84f,stroke-width:2px,color:#000;
    classDef red fill:#e9c7c7,stroke:#c0504d,stroke-width:2px,color:#000;

    class IA,PE input;
    class RA,SA,DA,INV middle;
    class RB1,RB2,NEG green;
    class NN red;
```

==== Why Not Flow Matching or Diffusion


==== Inference


=== Deep Learning, the Most and Least Important Part

_This part, including design and coding, is heavily (\~99%) assisted by LLMs._

==== Network

This part is very random currently. I just told LLMs to analyze the potential parameter count the model need to perform the task well, then have it design a random U-Net for me.

==== Optimizer

Muon@jordan2024muon optimizer is used in parameters with ndim $>= 2$, and AdamW@adamw is used for the rest. As Su suggests @kexuefm-11416, Muon's update RMS is matched against AdamW's, and parameters of convolution layers are reshaped to allow $"msign"$ to operate on it.

I observed a smoother loss curve for Muon-hybrid training than AdamW-only.

== Experiment

=== Implementation


== Demo Product


#bibliography("refs.bib")
