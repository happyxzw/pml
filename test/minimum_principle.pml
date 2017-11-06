include lib.either
include lib.nat
include lib.nat_proofs

type min<n,f> = ∀p ∈ nat, leq (f n) (f p) ≡ true

def total<f,a:ο> = ∀x∈a, ∃w:ι, f x ≡ w

type bot = ∀x:ο,x

type snat<o> = μ_o nat, [ Zero ; S of nat ]

val rec leq_size : ∀o, ∀m∈snat<o+1>, ∀n∈nat, either<leq m n ≡ true, n∈snat<o>> =
  fun m n {
    case m {
      Zero → case n {
          Zero → InL
          S[n] → InL
        }
      S[m] →
        case n {
          Zero → InR[Zero]
          S[n] →
            case m {  // case for n because leq use compare
              Zero  → case n { Zero → InL | S[_] → InL}
              S[m'] →
                case leq_size S[m'] n {
                  InL    → InL
                  InR[p] → InR[S[p]]
                  }
              }
          }
      }
  }

val rec fn : ∀f∈(nat ⇒ nat), total<f,nat> ⇒ ∀n∈nat, ∀q∈(nat | q ≡ f n),
    (∀n∈ nat, min<n,f> ⇒ bot) ⇒ bot =
  fun f ft n q k {
    let o such that q : snat<o+1>;
    k (n:nat) (fun p {
        use ft p;
        use leq_total q (f p);
        case leq_size (q:snat<o+1>) (f p) {
          InL     → {}
          InR[fp] → fn f ft p fp k
        }} : min<n,f>)
  }

val minimum_principle : ∀f∈(nat ⇒ nat), total<f,nat> ⇒ ∃n∈nat, min<n,f> =
  fun f ft {
    save s {
      let k : ∀n∈ nat, min<n,f> ⇒ bot = fun n mi { restore s (n, mi) };
      use ft Zero;
      fn f ft Zero (f Zero) k
    }
  }
