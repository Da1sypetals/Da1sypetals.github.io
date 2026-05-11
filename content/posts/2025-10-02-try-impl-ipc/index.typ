#import "/config.typ": template, tufted
#show: template.with(
  title: "Try To Implement IPC",
  date: datetime(year: 2025, month: 10, day: 2),
  lang: "en",
)

*Intro: A taste of the Rust programming language*

Recently, I tried to get started with Rust and wanted to write some code. I ended up picking up two papers I've been studying lately to try reproducing them.

**Note:** This post only reproduces/discusses the IPC family of algorithms.

Project repo: #link("https://github.com/Da1sypetals/ip-sim/")[Github]

== Implicit Euler

Physical simulation is essentially a numerical integration process.

Explicit integration tends to explode, but implicit integration suffers from a "chicken-and-egg" problem.

=== What Is It?

Incremental Potential (IP) is a function of the degrees of freedom (DOF) of a scene at time t, IP(t).

Implicit Euler constructs and minimizes the IP to obtain the position at the next timestep.

Deep learning typically uses gradient descent, but in graphics, empirical evidence suggests gradient descent performs poorly. So, we opt for Newton's method.

=== Implementation

- Newton's method is faster, but it introduces a problem: assembling the Hessian matrix.
- Fortunately, each component's Hessian has only tens to hundreds of entries, which can be stored sparsely.

Following this #link("https://zhuanlan.zhihu.com/p/444105016")[tutorial], I implemented springs with vertices pinned to a wall.

- Choosing libraries:
  - Used macroquad for GUI.
  - Used nalgebra_glm for small-scale linear algebra.
  - Switched to faer for large-scale sparse matrices.

== Contact IP

In short, Contact IP requires that point-edge pairs from two different bodies, which are close enough, are assigned energy based on their distance.

But to prevent interpenetration, there are additional requirements:
- Every intermediate step of the line search must ensure no primitive pairs penetrate.

=== Procedure

At each line search step in Newton's method:
- Traverse all primitive pairs and identify those with distances below the threshold.
- Compute the energy, gradient, and Hessian of the Contact IP.
- Perform a CCD operation to ensure the line search doesn't cause interpenetration.
- Use the Armijo condition for the line search.

=== Implementation

Every step involved endless debugging…

**Gradient & Hessian:**
- In 2D, each primitive pair's DOFs are 6.
- The gradient can still be computed manually (a 6D vector). But the Hessian is a 6×6 matrix.
- So, I used SymPy for symbolic computation and generated code from it.

**Note:** Later, I built my own SymPy→Rust code generator: #link("https://github.com/Da1sypetals/Symars")[Symars]

After days of coding and debugging, the demo finally worked:

#figure(image("ipc-1.gif"))

== ABD

TL;DR, ABD Replaces traditional 6-DOF rigid bodies with 12-DOF bodies and heavily penalizes transformation matrices that deviate too far from rotation matrices.

In 2D, an affine body has 6 DOFs: x = A x_0 + b.

ABD uses an orthogonal potential energy to penalize A and keep it close to a rotation matrix.

=== Implementation

- Any energy term requires second derivatives. Again, I used SymPy.
- Affine bodies also need contact handling:
  - Unlike mass-spring systems where each vertex is a DOF, an AB's vertex position p is a function of DOFs.

After more endless debugging and parameter tuning, the simulation finally ran:

#figure(image("ipc-2.gif"))

== Final Thoughts

The resulting code is a bona fide spaghetti monster.

Even though I spent a long time thinking about unifying interfaces before coding, the final design is neither OOP nor Rust-like, with inconsistent parameter passing everywhere.

The bright side:
- Cargo is amazing — adding a dependency takes three seconds.
- No memory issues (since I didn't need to write `unsafe` code).
