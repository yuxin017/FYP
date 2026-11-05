from google.cloud import firestore

PROJECT_ID = "ecotravel-5ad49"
COLLECTION = "heritage_attractions"

historical_data = {
    "H001": {
        "yearBuilt": "1897",
        "architecturalStyle": "Indo-Saracenic / Moorish Revival",
        "heritageStatus": "National Heritage Landmark",
        "conservationGuidelines": [
            "Use designated public areas and visitor pathways.",
            "Do not climb, scratch, or touch protected architectural features.",
            "Keep entrances and official access points clear.",
            "Dispose of rubbish properly and help keep Merdeka Square clean.",
        ],
        "visitorEtiquetteItems": [
            "Respect security instructions and restricted areas.",
            "Keep noise at a reasonable level around official buildings.",
            "Avoid blocking entrances while taking photographs.",
            "Respect ceremonies, events, and other visitors.",
        ],
        "dressCode": [
            "Comfortable and respectful casual wear is suitable.",
            "Wear suitable footwear for walking around the heritage area.",
        ],
        "photographyRestrictions": [
            "Outdoor photography is generally suitable in public areas.",
            "Do not photograph restricted or security-sensitive areas.",
            "Avoid blocking pedestrian and vehicle access for photos.",
        ],
        "preservationPractices": [
            "Do not touch or damage historic walls and decorative features.",
            "Stay within public visitor areas.",
            "Report visible damage or vandalism to the relevant authority.",
        ],
    },

    "H002": {
        "yearBuilt": "17th century",
        "architecturalStyle": "Traditional shophouses / Peranakan influence",
        "heritageStatus": "Melaka UNESCO World Heritage Area",
        "conservationGuidelines": [
            "Respect historic shophouse façades and private properties.",
            "Do not paste stickers, write on, or damage heritage buildings.",
            "Keep pedestrian areas and drains free from rubbish.",
            "Support conservation by using designated walkways and public spaces.",
        ],
        "visitorEtiquetteItems": [
            "Respect residents, shop owners, and local businesses.",
            "Keep noise controlled, especially near residential properties.",
            "Queue politely at popular shops and food stalls.",
            "Keep the street clean and use available rubbish bins.",
        ],
        "dressCode": [
            "Light, comfortable clothing is suitable for walking.",
            "Wear comfortable footwear due to the long pedestrian route.",
        ],
        "photographyRestrictions": [
            "Ask permission before photographing people closely.",
            "Do not enter private shops or homes only to take photographs.",
            "Avoid blocking shop entrances and busy pedestrian paths.",
        ],
        "preservationPractices": [
            "Protect original shophouse façades and decorative features.",
            "Avoid touching fragile displays or historic objects.",
            "Support local heritage businesses and traditional crafts.",
        ],
    },

    "H003": {
        "yearBuilt": "Hindu shrine established in the late 19th century",
        "architecturalStyle": "Hindu temple complex / Natural limestone cave",
        "heritageStatus": "Major Hindu Pilgrimage Site",
        "conservationGuidelines": [
            "Do not damage limestone formations, temple structures, or statues.",
            "Keep the caves, stairs, and temple grounds free from rubbish.",
            "Follow signs and remain within visitor-accessible areas.",
            "Do not feed or disturb monkeys and other wildlife.",
        ],
        "visitorEtiquetteItems": [
            "Respect worshippers, ceremonies, and prayer areas.",
            "Remove footwear where temple rules require it.",
            "Keep voices low inside shrines and prayer spaces.",
            "Follow instructions provided by temple staff.",
        ],
        "dressCode": [
            "Wear respectful clothing that covers shoulders and knees.",
            "Use comfortable footwear for the long staircase.",
        ],
        "photographyRestrictions": [
            "Avoid flash or photography where signs prohibit it.",
            "Ask permission before photographing worshippers or ceremonies.",
            "Do not interrupt religious activities for photographs.",
        ],
        "preservationPractices": [
            "Do not write on cave walls or temple structures.",
            "Do not remove stones, plants, or natural materials.",
            "Help protect wildlife by keeping food secured and not feeding animals.",
        ],
    },

    "H004": {
        "yearBuilt": "1511",
        "architecturalStyle": "Portuguese military fortification",
        "heritageStatus": "Historic Monument in Melaka UNESCO World Heritage Area",
        "conservationGuidelines": [
            "Do not climb unstable or restricted sections of the ruins.",
            "Do not scratch, carve, or write on historic stone surfaces.",
            "Keep the monument and surrounding grounds free from rubbish.",
            "Use established visitor paths around the gateway.",
        ],
        "visitorEtiquetteItems": [
            "Allow other visitors space to view and photograph the monument.",
            "Respect barriers and conservation signs.",
            "Keep children supervised around uneven historic surfaces.",
            "Avoid loud or disruptive behaviour around the monument.",
        ],
        "dressCode": [
            "Comfortable casual clothing is suitable.",
            "Wear stable footwear for uneven stone and outdoor surfaces.",
        ],
        "photographyRestrictions": [
            "Photography is suitable from public visitor areas.",
            "Do not climb the monument to obtain photographs.",
            "Avoid placing equipment against historic masonry.",
        ],
        "preservationPractices": [
            "Do not remove stones or fragments from the site.",
            "Avoid touching fragile or weathered masonry unnecessarily.",
            "Report vandalism or visible damage to site authorities.",
        ],
    },

    "H005": {
        "yearBuilt": "1891–1905",
        "architecturalStyle": "Chinese Buddhist with Thai and Burmese influences",
        "heritageStatus": "Major Buddhist Cultural Landmark",
        "conservationGuidelines": [
            "Respect temple buildings, statues, gardens, and prayer spaces.",
            "Do not touch religious objects unless visitors are invited to do so.",
            "Keep temple grounds clean and use designated rubbish bins.",
            "Follow signs and remain within areas open to visitors.",
        ],
        "visitorEtiquetteItems": [
            "Keep voices low around prayer halls and worshippers.",
            "Show respect during religious ceremonies and rituals.",
            "Follow temple instructions regarding footwear.",
            "Do not interrupt worshippers for photographs.",
        ],
        "dressCode": [
            "Wear modest clothing suitable for a Buddhist temple.",
            "Avoid clothing that is overly revealing in prayer areas.",
        ],
        "photographyRestrictions": [
            "Check signs before taking photographs inside prayer halls.",
            "Ask permission before photographing monks or worshippers closely.",
            "Avoid flash photography around religious objects where restricted.",
        ],
        "preservationPractices": [
            "Do not touch, climb, or lean on statues and historic structures.",
            "Protect landscaped areas by staying on visitor paths.",
            "Use reusable bottles and avoid leaving disposable waste.",
        ],
    },
}


def main():
    db = firestore.Client(project=PROJECT_ID)
    batch = db.batch()

    for document_id, data in historical_data.items():
        ref = db.collection(COLLECTION).document(document_id)

        # merge=True means ONLY these historical fields are added/updated.
        # Existing imageUrl, name, history, audio text, etc. remain unchanged.
        batch.set(ref, data, merge=True)

    batch.commit()

    print("Historical information uploaded successfully.")
    print(f"Updated {len(historical_data)} Firestore documents:")
    for document_id in historical_data:
        print(f"  - {document_id}")


if __name__ == "__main__":
    main()
