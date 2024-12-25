#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")
 

// ################### Content ###################

= Trust-Region Eigenvalue Filtering for Projected Newton

== Algorithm

#image("assets/001.jpg")
#image("assets/002.jpg")

== Simulation Pipeline
The described algorithm is run _*once each Newton-Raphson iteration*_.

#let ff=$bold(upright(F))$

- System hessian $H_"sys"=bold(upright(0)) $ 
- For $e$ in elements:
  - $x^p_0,x^p_1,x^p_2,x^p_3=e."nodes"_(i-1)$ `// nodes at timestep i-1`
  - $x_0,x_1,x_2,x_3=e."nodes"_(i)$ `// nodes at timestep i`
  - $rho = (Psi(x_0,x_1,x_2,x_3)-Psi(x^p_0,x^p_1,x^p_2,x^p_3))/(psi(x_0,x_1,x_2,x_3)-psi(x^p_0,x^p_1,x^p_2,x^p_3))$
  - $Lambda, U = "eig"((partial^2 Psi(x_0,x_1,x_2,x_3))/(partial "concat"(x_0,x_1,x_2,x_3)^2))$ `// deformation gradient at timestep i`
  - $Lambda_("projected") =$ `if ` $abs(rho-1)<epsilon$ `{ `$max(Lambda, 0)$` } else { ` $abs(Lambda)$ ` }`
  - $H_(e, "projected") = U Lambda_("projected") U^T $
  - $H_"sys" $ `+=` $ H_(e, "projected")$


Where $Psi$ is the element energy, $psi$ is its *quadratic approximation*: 
$
  psi(x_0,x_1,x_2,x_3)=Phi(x)+g^T x+1/2 x^T H x
$
with $g$ the gradient and $H$ the (original, not-projected) hessian of $Phi$ at $(x_0,x_1,x_2,x_3)$ (the word _quadractic approximation_ indicates the non-projection of $H$).