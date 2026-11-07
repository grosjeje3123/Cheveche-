#!/usr/bin/env python3
"""Fabrique les sons de Chevêche par synthèse (aucun enregistrement, aucune licence à gérer).

Usage : python3 tools/make_sounds.py [dossier]   (par défaut assets/sounds)
Chaque son est court, doux et mat : rien de « casino ». Pour les remplacer par de vrais sons,
il suffit de déposer des .wav de même nom dans assets/sounds.
"""
import math, os, random, struct, sys, wave

RATE = 44100


def write(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    if peak > 1.0:
        samples = [s / peak for s in samples]
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


def env(t, attack, tau):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / tau)


def note(freq, dur, tau, amp, harmonics=((2, 0.25),), attack=0.004):
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        v = math.sin(2 * math.pi * freq * t)
        for k, a in harmonics:
            v += a * math.sin(2 * math.pi * freq * k * t)
        out.append(amp * env(t, attack, tau) * v)
    return out


def mix(length, *parts):
    out = [0.0] * int(length * RATE)
    for start, samples in parts:
        o = int(start * RATE)
        for i, s in enumerate(samples):
            if o + i < len(out):
                out[o + i] += s
    return out


def noise_burst(dur, tau, amp, seed):
    rnd = random.Random(seed)
    out, prev = [], 0.0
    for i in range(int(dur * RATE)):
        x = rnd.uniform(-1, 1)
        hp = x - prev          # passe-haut grossier : un « clic » sec plutôt qu'un souffle
        prev = x
        out.append(amp * env(i / RATE, 0.0005, tau) * hp)
    return out


def _passe_bas(a):
    """Filtre passe-bas à un pôle (coefficient `a`), à appliquer échantillon par échantillon."""
    etat = [0.0]

    def f(x):
        etat[0] += a * (x - etat[0])
        return etat[0]
    return f


def _coef(freq):
    return 1 - math.exp(-2 * math.pi * freq / RATE)


def scratch_loop(dur=1.6, fade=0.2, seed=7):
    """Frottement feutré, comme une gomme sur du papier : bruit gardé entre ~200 Hz et ~1,2 kHz
    (deux passe-bas en série, donc des aigus nettement coupés), animé par des grains longs dont
    l'enveloppe est lissée : pas de crépitement sec."""
    rnd = random.Random(seed)
    n = int(dur * RATE) + int(fade * RATE)
    bas1, bas2 = _passe_bas(_coef(1200)), _passe_bas(_coef(1200))
    grave = _passe_bas(_coef(200))
    lisse = _passe_bas(_coef(1 / (2 * math.pi * 0.018)))   # ~18 ms : les grains se fondent
    grain, grain_left, raw = 0.7, 0, []
    for _ in range(n):
        if grain_left <= 0:
            grain = rnd.uniform(0.55, 1.0)
            grain_left = int(rnd.uniform(0.03, 0.07) * RATE)
        grain_left -= 1
        x = bas2(bas1(rnd.uniform(-1, 1)))
        x -= grave(x)
        raw.append(x * lisse(grain))
    body = int(dur * RATE)
    f = int(fade * RATE)
    # Boucle sans couture : la fin se fond dans le début (fondu à puissance constante).
    out = raw[:body]
    for i in range(f):
        k = i / f
        out[i] = out[i] * math.sin(k * math.pi / 2) + raw[body + i] * math.cos(k * math.pi / 2)
    peak = max(abs(s) for s in out)
    return [0.4 * s / peak for s in out]


def tampon(seed=11):
    """Un tampon encreur posé sur le papier, sur une table : un « tchok » mat et grave (le bois du manche et la table,
    une note qui chute vite de 150 à 80 Hz), le froissement très court du papier pressé (bruit feutré, sous 1,8 kHz),
    puis un minuscule second contact quand le tampon se relève. Rien d'aigu ni de métallique."""
    rnd = random.Random(seed)
    n = int(0.32 * RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 80 + 70 * math.exp(-t / 0.018)
        phase += 2 * math.pi * f / RATE
        a = min(1.0, t / 0.0015) * math.exp(-t / 0.055)
        out[i] += 0.6 * a * math.sin(phase)
        # Le bois du manche : deux résonances mates (vers 330 et 690 Hz), qui portent le son sur un haut-parleur
        # de téléphone, trop petit pour les graves.
        bois = min(1.0, t / 0.001) * math.exp(-t / 0.028)
        out[i] += 0.55 * bois * math.sin(2 * math.pi * 330 * t + 0.3)
        out[i] += 0.28 * bois * math.exp(-t / 0.02) * math.sin(2 * math.pi * 690 * t)
    papier = _passe_bas(_coef(1800))
    papier2 = _passe_bas(_coef(1800))
    for i in range(int(0.06 * RATE)):
        t = i / RATE
        out[i] += 0.8 * min(1.0, t / 0.001) * math.exp(-t / 0.014) * papier2(papier(rnd.uniform(-1, 1))) * 3.0
    relache = int(0.17 * RATE)   # le tampon se relève : un contact léger, plus sourd
    sourd = _passe_bas(_coef(700))
    for i in range(int(0.03 * RATE)):
        t = i / RATE
        out[relache + i] += 0.12 * math.exp(-t / 0.008) * sourd(rnd.uniform(-1, 1)) * 3.0
    peak = max(abs(v) for v in out)
    out = [0.7 * v / peak for v in out]
    m = int(0.03 * RATE)
    for i in range(m):   # fin sans clic
        out[-1 - i] *= i / m
    return out


def mallet(freq, dur, amp, tau=0.35):
    """Note de marimba douce : une fondamentale et un partiel aigu qui s'éteint vite (attaque feutrée)."""
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        a = min(1.0, t / 0.006)
        v = math.sin(2 * math.pi * freq * t) * math.exp(-t / tau)
        v += 0.18 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-t / (tau * 0.18))
        v += 0.06 * math.sin(2 * math.pi * freq * 10 * t) * math.exp(-t / (tau * 0.06))
        out.append(amp * a * v)
    return out


def jingle(notes, length, amp=0.22):
    """`notes` : [(départ en s, fréquence, durée)]."""
    return mix(length, *[(t, mallet(f, d, amp)) for t, f, d in notes])


def hz(nom):
    """« E4 », « G#4 »… -> fréquence (la 440)."""
    notes = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n, alt, octave = nom[0], nom[1:-1], int(nom[-1])
    demi = notes[n] + (1 if alt == "#" else -1 if alt == "b" else 0) + 12 * (octave - 4)
    return 440.0 * 2 ** (demi / 12)


def marimba(f, dur, amp, tau=None):
    """Lame de marimba : fondamentale, partiel à 3,93× (le timbre boisé), attaque de maillet un peu sèche."""
    tau = tau or max(0.18, 0.55 - (f - 200) / 2400)   # les notes graves sonnent plus longtemps
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        a = min(1.0, t / 0.002)
        v = math.sin(2 * math.pi * f * t) * math.exp(-t / tau)
        v += 0.30 * math.sin(2 * math.pi * f * 3.93 * t) * math.exp(-t / (tau * 0.16))
        v += 0.10 * math.sin(2 * math.pi * f * 9.2 * t) * math.exp(-t / (tau * 0.05))
        out.append(amp * a * v)
    return out


def tremolo(t, f, dur, amp, pas=0.052):
    """Trémolo de marimba : la même lame frappée vite par deux maillets, qui s'éteint."""
    parts, k = [], 0
    while k * pas < dur:
        a = amp * (0.75 + 0.25 * (k % 2)) * (1 - k * pas / dur) ** 1.3
        parts.append((t + k * pas, marimba(f, 0.5, a)))
        k += 1
    return parts


def salle(x, mix=0.22):
    """Un peu d'espace : quelques échos très courts qui s'éteignent."""
    out = list(x) + [0.0] * int(0.5 * RATE)
    eco = [0.0] * len(out)
    for d_ms, g in ((29, 0.4), (43, 0.34), (61, 0.28), (83, 0.22)):
        d = int(d_ms / 1000 * RATE)
        buf = [0.0] * len(out)
        for i in range(len(out)):
            buf[i] = (out[i] if i < len(x) else 0.0) + (g * buf[i - d] if i >= d else 0.0)
        for i in range(len(out)):
            eco[i] += buf[i]
    return [out[i] + mix * 0.25 * eco[i] for i in range(len(out))]


def ouverture():
    """Le thème d'ouverture (original) : marimba à l'espagnole, gamme andalouse sur mi. Un appel qui monte,
    un accent à contretemps, la descente andalouse, la chute sur mi, puis l'envol en trémolo sur le mi aigu."""
    s = 0.105   # une double croche, environ 143 à la noire
    melodie = [(0, "E4"), (1, "F4"), (2, "G#4"), (3, "A4"), (5, "C5"), (7, "B4"), (8, "A4"),
               (9, "G#4"), (11, "F4"), (12, "E4"), (15, "G#4"), (16, "B4"), (17, "D5")]
    parts = []
    for pas, n in melodie:
        parts.append((pas * s, marimba(hz(n), 0.9, 0.16 * (1.25 if pas in (5, 9, 12) else 1.0))))
        if pas in (3, 5, 9, 12):  # doublure une octave en dessous sur les appuis
            parts.append((pas * s, marimba(hz(n) / 2, 0.9, 0.08)))
    t_fin = 18 * s
    parts += tremolo(t_fin, hz("E5"), 1.15, 0.13)
    parts += tremolo(t_fin, hz("B4"), 1.15, 0.07)
    parts.append((t_fin, marimba(hz("E3"), 1.4, 0.14)))
    x = salle(mix(3.4, *parts))
    actif = [v for v in x if abs(v) > 0.005]
    k = 0.07 / math.sqrt(sum(v * v for v in actif) / len(actif))   # même niveau que les sons écoutés
    x = [v * k for v in x]
    n = int(0.12 * RATE)
    for i in range(n):  # fondu final
        x[-1 - i] *= i / n
    return x


def main(folder):
    os.makedirs(folder, exist_ok=True)
    write(os.path.join(folder, "tap.wav"), noise_burst(0.03, 0.004, 0.35, 1))
    write(os.path.join(folder, "clue.wav"),
          mix(0.3, (0.0, noise_burst(0.02, 0.004, 0.18, 2)), (0.005, note(1046.5, 0.28, 0.07, 0.22, ((3, 0.08),)))))
    write(os.path.join(folder, "right.wav"),
          mix(0.7, (0.0, note(784.0, 0.6, 0.16, 0.26)), (0.09, note(1046.5, 0.6, 0.2, 0.26))))
    write(os.path.join(folder, "wrong.wav"),
          mix(0.5, (0.0, note(329.6, 0.35, 0.09, 0.24, ((3, 0.1),))), (0.1, note(261.6, 0.4, 0.12, 0.24, ((3, 0.1),)))))
    write(os.path.join(folder, "scratch.wav"), scratch_loop())
    # Page « Fiche complète » : le tampon qui se pose.
    write(os.path.join(folder, "stamp.wav"), tampon())
    # Ouverture (au lancement seulement) : un petit thème de marimba à l'espagnole.
    write(os.path.join(folder, "startup.wav"), ouverture())
    # Fin de série : trois petites phrases, de la plus enjouée à la plus retenue (jamais triste).
    C5, E5, G5, C6, E6, G4, A4 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 392.0, 440.0
    write(os.path.join(folder, "series_great.wav"),
          jingle([(0.0, G4, 0.5), (0.11, C5, 0.5), (0.22, E5, 0.5), (0.33, G5, 0.6),
                  (0.5, C6, 1.2), (0.5, E5, 1.2), (0.5, G5, 1.2)], 1.8))
    write(os.path.join(folder, "series_good.wav"),
          jingle([(0.0, C5, 0.5), (0.13, E5, 0.5), (0.26, G5, 1.0), (0.26, C5, 1.0)], 1.4))
    write(os.path.join(folder, "series_low.wav"),
          jingle([(0.0, A4, 0.7), (0.18, C5, 1.0), (0.18, E5, 1.0)], 1.3, amp=0.2))
    print("sons écrits dans", folder)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "sounds"))
