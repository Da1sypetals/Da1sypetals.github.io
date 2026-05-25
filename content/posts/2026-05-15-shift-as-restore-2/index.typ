#import "/config.typ": template, tufted
#show: template.with(
  title: "Shift as Restore, Ep. 2: Flow Matching on loseless representation",
  date: datetime(year: 2026, month: 5, day: 15),
)


== Background

#link("../2026-05-10-shift-as-restore", "Attempt 1") operates on Mel-Spectrogram, which is a lossy representation. Attempt 2 tries to operate on loseless represenation of the audio, in an attempt to improve theoretical ceiling of the algorithm's performance.

== Representation & Loss

Choices from prior works mainly includes STFT (cites), MDCT (cites). I start from STFT following FlowDec (cite), but quickly encounter blockers: the distribution of my data is significantly different from theirs, and some assumptions can no longer be used, causing the FlowDec method to perform very badly in our task.

After a long discussion with LLMs, we decided that it is because other parts of FlowDec does not suit our task well, and STFT is not the problem.


== V2: A Fruitful Failure

Jointly optimizing magnitude and phase (or real and imaginary) is hard.


= TODO
