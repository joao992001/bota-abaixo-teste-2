"""Monta a prancha dos robôs e as comparações lado a lado com as referências.
Rodar depois de robos.py: python3 art/src/prancha.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
R = os.path.join(ROOT, "art/out/game/robo")
OUT = os.path.join(ROOT, "art/out")
TEAL = (58, 167, 163)
EXPRS = ["normal", "esforco", "susto", "vitoria", "eliminado"]
ACCS = [None, "capacete", "bone", "gorro"]


def img(name):
    return Image.open(os.path.join(R, name)).convert("RGBA")


def robot(ci, expr="normal", acc=None, s=1.0, hammer_rot=-40):
    """Robô montado (mesma montagem que a Godot usa). s = escala sobre 1x de jogo."""
    k = 2  # PNGs estão em 2x
    canvas = Image.new("RGBA", (128 * k, 128 * k))
    ham = img("marreta.png").rotate(hammer_rot, resample=Image.BICUBIC, center=(32 * k, 54 * k))
    canvas.alpha_composite(ham, (int((94 - 32) * k), int((94 - 54) * k)))
    foot = img("pe.png")
    for fx in (52, 76):
        canvas.alpha_composite(foot, (int((fx - 16) * k), int((113 - 11) * k)))
    canvas.alpha_composite(img(f"corpo_p{ci + 1}.png"))
    canvas.alpha_composite(img(f"rosto_{expr}.png"))
    if acc:
        canvas.alpha_composite(img(f"acc_{acc}.png"))
    hand = img("mao.png")
    canvas.alpha_composite(hand, (int((94 - 12) * k), int((94 - 12) * k)))
    canvas.alpha_composite(hand, (int((40 - 12) * k), int((98 - 12) * k)))
    if s != 1.0:
        canvas = canvas.resize((int(128 * s), int(128 * s)), Image.LANCZOS)
    else:
        canvas = canvas.resize((128, 128), Image.LANCZOS)
    return canvas


def font(sz):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def prancha_robos():
    W, H = 1920, 1080
    im = Image.new("RGBA", (W, H), TEAL + (255,))
    d = ImageDraw.Draw(im)
    d.text((40, 24), "Robôs — 4 cores, 5 expressões, 3 acessórios (escala 3x)", font=font(40), fill="white")
    for ci in range(4):  # fileira 1: 4 cores com acessório, escala 3x
        im.alpha_composite(robot(ci, "normal", ACCS[ci], 3.0), (40 + ci * 400, 60))
    for i, e in enumerate(EXPRS):  # fileira 2: expressões em 2,5x
        im.alpha_composite(robot(i % 4, e, None, 2.5), (40 + i * 370, 450))
        d.text((150 + i * 370, 770), e, font=font(30), fill="white")
    # fileira 3: tamanho real de jogo (1x) sobre o fundo
    d.text((40, 840), "Tamanho real no jogo (1x):", font=font(30), fill="white")
    for ci in range(4):
        im.alpha_composite(robot(ci, EXPRS[ci], ACCS[ci], 1.0), (480 + ci * 140, 900))
    im.convert("RGB").save(os.path.join(OUT, "prancha_robos.png"))


def side_by_side(ref_path, ours, out_name, label_ref, label_ours, h=700, crop=None):
    ref = Image.open(ref_path).convert("RGB")
    if crop:
        ref = ref.crop(crop)
    ref = ref.resize((int(ref.width * h / ref.height), h), Image.LANCZOS)
    if isinstance(ours, str):
        ours = Image.open(ours).convert("RGB")
    ours = ours.convert("RGB").resize((int(ours.width * h / ours.height), h), Image.LANCZOS)
    out = Image.new("RGB", (ref.width + ours.width + 30, h + 60), (20, 14, 24))
    out.paste(ref, (0, 60))
    out.paste(ours, (ref.width + 30, 60))
    d = ImageDraw.Draw(out)
    d.text((10, 12), label_ref, font=font(32), fill="white")
    d.text((ref.width + 40, 12), label_ours, font=font(32), fill="white")
    out.save(os.path.join(OUT, out_name))


if __name__ == "__main__":
    prancha_robos()
    side_by_side(os.path.join(ROOT, "docs/referencias/ref4_ultimate_chicken_horse.png"),
                 os.path.join(OUT, "prancha_robos.png"), "comparacao_robos.png",
                 "Referência 4 (carisma, acessórios)", "Bota-Abaixo: robôs", crop=(25, 28, 985, 398))
    side_by_side(os.path.join(ROOT, "docs/referencias/ref1_battleblock_theater.png"),
                 os.path.join(OUT, "prancha_canteiro.png"), "comparacao_canteiro.png",
                 "Referência 1 (blocos, céu, plateia)", "Bota-Abaixo: Canteiro (captura do jogo)", crop=(45, 75, 1003, 612))
    print("ok")
