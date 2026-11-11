"""Catalogue-trained retrieval, spatial queue density and visual landmark matching."""
import base64
import math
import cv2
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.neighbors import KernelDensity, NearestNeighbors
from scipy.sparse import csr_matrix
from sklearn.ensemble import IsolationForest


def recommendations(data):
    places = data.get('places', [])[:1000]
    if not places:
        return {'recommendations': [], 'method': 'TF-IDF cosine neighbours'}
    documents = [' '.join(str(p.get(k, '')) for k in ['name', 'category', 'description']) for p in places]
    query = ' '.join(data.get('interests', []) + data.get('foodPreferences', []))
    vectorizer = TfidfVectorizer(analyzer='char_wb', ngram_range=(2, 4), max_features=12000, sublinear_tf=True)
    vectors = vectorizer.fit_transform(documents)
    target = vectorizer.transform([query])
    by_id = {p['id']: i for i, p in enumerate(places)}
    rated = [r for r in data.get('ratings', []) if r.get('attractionId') in by_id and r.get('rating', 0) >= 4]
    if rated:
        target = target + csr_matrix(vectors[[by_id[r['attractionId']] for r in rated]].mean(axis=0)) * .6
    neighbours = NearestNeighbors(metric='cosine', algorithm='brute').fit(vectors)
    distances, indices = neighbours.kneighbors(target, n_neighbors=len(places))
    rows = []
    for distance, i in zip(distances[0], indices[0]):
        place = places[int(i)]
        if place.get('status') != 'open':
            continue
        height = data.get('heightCm')
        if place.get('minHeightCm', 0) > 0 and (height is None or height < place['minHeightCm']):
            continue
        relevance = max(0, min(1, 1-float(distance)))
        popularity = max(0, min(1, float(place.get('ratingAverage') or 0)/5))
        score = relevance * .85 + popularity * .15
        rows.append({'id': place['id'], 'score': round(score, 5), 'reason': 'Similar to your interests and highly rated visits.' if rated and relevance > .1 else 'Matches your saved park preferences.' if relevance > .1 else 'An available experience to explore.'})
    return {'recommendations': sorted(rows, key=lambda r: (-r['score'], r['id'])), 'method': 'TF-IDF cosine neighbours'}


def queue_density(data):
    points = data.get('points', [])[:1024]
    active = [p for p in points if all(isinstance(p.get(k), (int, float)) and math.isfinite(p[k]) for k in ['x', 'y', 'weight']) and 0 <= p['x'] <= 1 and 0 <= p['y'] <= 1 and p['weight'] > 0]
    size = 32
    axis = np.linspace(0, 1, size)
    grid = np.array([(x, y) for y in axis for x in axis])
    if active:
        estimator = KernelDensity(kernel='gaussian', bandwidth=.09).fit(np.array([[p['x'], p['y']] for p in active]), sample_weight=np.array([p['weight'] for p in active]))
        density = np.exp(estimator.score_samples(grid))
        density = density/max(float(density.max()), 1e-9)
    else:
        density = np.zeros(size*size)
    return {'size': size, 'values': np.round(density, 4).tolist(), 'queuePlaces': sum(p['weight'] for p in active), 'method': 'Gaussian kernel density estimation', 'source': 'Confirmed attraction queue places'}


def anomalies(data):
    samples = data.get('samples', [])[:5000]
    features = np.array([[math.log1p(max(0,float(s.get(k,0)))) for k in ['reservations','cancellations','missed','orders','spendMinor','sessions']] for s in samples])
    learned = len(samples)>=20
    scores = IsolationForest(n_estimators=150,contamination=.08,random_state=42,n_jobs=1).fit(features).decision_function(features) if learned else np.ones(len(samples))
    flags=[]
    for sample,score in zip(samples,scores):
        reasons=[]
        if sample.get('reservations',0)>=30 and sample.get('cancellations',0)/sample['reservations']>.8:
            reasons.append('High number and proportion of cancelled reservations')
        if sample.get('missed',0)>=5:
            reasons.append('Repeated missed return windows')
        if sample.get('sessions',0)>=10:
            reasons.append('Many active device sessions')
        if learned and score<0:
            reasons.append('Activity differs from the current visitor activity pattern')
        if reasons:
            flags.append({'uid':sample['uid'],'reasons':reasons,'metrics':{k:sample.get(k,0) for k in ['reservations','cancellations','missed','orders','spendMinor','sessions']},'score':round(float(-score),5) if learned else None})
    return {'flags':sorted(flags,key=lambda f:-(f['score'] or 0)),'method':'Isolation Forest with review rules' if learned else 'Review rules; at least 20 active visitors needed for learned detection','samples':len(samples)}


FAQ = [
    ('ticket', 'tickets passes buy booking admission price 门票 买票 入场 价格 tiket beli harga tempahan',
     ['Open Tickets to compare the current pass prices, choose your visit day and add each guest. Confirmed tickets and their QR passes appear in My Tickets.', 'Buka Tiket untuk melihat harga pas semasa, pilih tarikh lawatan dan tambah setiap tetamu. Tiket yang disahkan dan pas QR dipaparkan dalam Tiket Saya.', '打开门票页面查看当前票价，选择游园日期并填写每位游客资料。确认后的门票和二维码会显示在“我的门票”。'], 'tickets'),
    ('queue', 'queue reserve reservation return time ride 排队 预约 游乐 返场 masa giliran tempah tarikan',
     ['Open Virtual Queue, choose an attraction and an available return time. You need a valid park ticket and must meet its height requirement. Show your entrance pass during the reserved window.', 'Buka Barisan Maya, pilih tarikan dan masa kembali yang tersedia. Anda memerlukan tiket taman yang sah dan mesti memenuhi syarat ketinggian. Tunjukkan pas masuk dalam tempoh tempahan.', '打开虚拟排队，选择项目和可预约的返场时间。你需要有效门票并符合身高要求，请在预约时段出示入场码。'], 'queue'),
    ('photos', 'photo selfie gallery face matching print kiosk 照片 自拍 相册 人脸 打印 foto gambar cetak wajah kiosk',
     ['Open My Park Photos. Find photos using optional face matching or a photographer’s photo code. You can edit a preview, purchase digital or printed copies and open your collection pass for the kiosk.', 'Buka Foto Taman Saya. Cari gambar melalui padanan wajah pilihan atau kod foto jurugambar. Anda boleh mengedit pratonton, membeli salinan digital atau cetakan dan membuka pas pengambilan kiosk.', '打开“我的园区照片”，使用自愿人脸匹配或摄影师提供的照片码查找照片。你可以编辑预览、购买电子版或打印版，并用取件码到照片亭领取。'], 'photos'),
    ('groups', 'group family friends invite join location 群组 家人 朋友 邀请 加入 位置 kumpulan keluarga rakan jemput lokasi',
     ['Open My Groups to create or join a group, link each person’s ticket and reserve together. Location sharing is optional and can be stopped at any time.', 'Buka Kumpulan Saya untuk mencipta atau menyertai kumpulan, pautkan tiket setiap ahli dan buat tempahan bersama. Perkongsian lokasi adalah pilihan dan boleh dihentikan pada bila-bila masa.', '打开“我的群组”创建或加入群组，关联每位成员的门票后即可一起预约。位置共享完全自愿，可以随时关闭。'], 'groups'),
    ('rewards', 'points loyalty reward voucher redeem balance 积分 奖励 优惠券 兑换 baki mata ganjaran baucar tebus',
     ['Your profile opens Points & Vouchers. Collect eligible ticket-purchase points, review your activity and redeem rewards from the current catalogue. Each voucher shows its terms and expiry date.', 'Profil anda membuka Mata & Baucar. Kumpul mata pembelian tiket yang layak, semak aktiviti dan tebus ganjaran daripada katalog semasa. Setiap baucar memaparkan syarat dan tarikh luput.', '从个人页面打开“积分与优惠券”，领取符合条件的购票积分、查看记录并兑换当前目录中的奖励。每张优惠券均显示使用条款和到期日期。'], 'rewards'),
    ('support', 'help emergency safety lost first aid support complaint 帮助 紧急 安全 失物 急救 投诉 bantuan kecemasan keselamatan hilang pertolongan aduan',
     ['For an urgent safety issue, contact the nearest park staff member immediately. Open Help & Support to send a question, complaint or attachment and follow the reply in your account.', 'Untuk isu keselamatan segera, hubungi petugas taman terdekat. Buka Bantuan & Sokongan untuk menghantar soalan, aduan atau lampiran dan lihat balasan dalam akaun anda.', '如有紧急安全问题，请立即联系附近工作人员。你也可以打开“帮助与支持”提交问题、投诉或附件，并在账户中查看回复。'], 'support'),
    ('map', 'map directions navigate toilet dining restaurant shop where 地图 导航 厕所 餐厅 商店 在哪里 peta arah tandas restoran kedai mana',
     ['Open Park Map to search attractions, dining, shops and facilities. Choose your current landmark and destination. Device positioning and walking directions depend on the available venue services.', 'Buka Peta Taman untuk mencari tarikan, restoran, kedai dan kemudahan. Pilih mercu tanda semasa dan destinasi. Kedudukan peranti dan arah berjalan bergantung pada perkhidmatan lokasi yang tersedia.', '打开园区地图搜索游乐项目、餐饮、商店和设施，选择当前位置地标及目的地。设备定位和步行导航取决于园区已连接的服务。'], 'map'),
]


def assistant(data):
    message = str(data.get('message', '')).strip()
    language = data.get('language', 'en')
    if language not in ['en', 'ms', 'zh'] or len(message) < 2 or len(message) > 1000:
        raise ValueError('Enter a question of up to 1,000 characters.')
    index = ['en', 'ms', 'zh'].index(language)
    places = data.get('places', [])[:1000]
    docs = [q[1] for q in FAQ] + [str(p['name']) for p in places]
    vectorizer = TfidfVectorizer(analyzer='char', ngram_range=(2, 4), sublinear_tf=True)
    vectors = vectorizer.fit_transform(docs)
    scores = (vectors @ vectorizer.transform([message]).T).toarray().ravel()
    winner = int(scores.argmax())
    if float(scores[winner]) < .045:
        return {'answer': ['I can help with park tickets, queues, maps, groups, photos and rewards. Try naming the feature or attraction you need. For personal account issues, open Help & Support.', 'Saya boleh membantu tentang tiket, giliran, peta, kumpulan, foto dan ganjaran. Nyatakan ciri atau tarikan yang anda perlukan. Untuk isu akaun peribadi, buka Bantuan & Sokongan.', '我可以帮助你了解门票、排队、地图、群组、照片和积分。请说明功能或项目名称。账户个人问题请打开“帮助与支持”。'][index], 'actions': ['support'], 'source': 'Park help guide'}
    if winner < len(FAQ):
        item = FAQ[winner]
        return {'answer': item[2][index], 'actions': [item[3]], 'source': 'Park help guide'}
    place = places[winner-len(FAQ)]
    status = {'open': ['Open', 'Dibuka', '开放'], 'closed': ['Closed', 'Ditutup', '关闭'], 'maintenance': ['Maintenance', 'Penyelenggaraan', '维护中']}.get(place.get('status'), ['Not reported', 'Belum dilaporkan', '未提供'])[index]
    name = place['name']
    wait = place.get('standbyMinutes')
    details = [f"{name}: {status}. Minimum height: {place.get('minHeightCm', 0)} cm.", f"{name}: {status}. Ketinggian minimum: {place.get('minHeightCm', 0)} cm.", f"{name}：{status}。最低身高：{place.get('minHeightCm', 0)} 厘米。"][index]
    if wait is not None:
        details += [f' Reported standby wait: {wait} minutes.', f' Masa menunggu yang dilaporkan: {wait} minit.', f' 已公布等候时间：{wait} 分钟。'][index]
    return {'answer': details, 'actions': ['map'], 'placeId': place['id'], 'source': 'Current park catalogue'}


def landmark_features(encoded):
    try:
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > 2_000_000:
            raise ValueError()
        image = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_GRAYSCALE)
        if image is None:
            raise ValueError()
    except Exception:
        raise ValueError('Choose a readable landmark photo smaller than 2 MB.') from None
    h, w = image.shape
    if max(h, w) > 1200:
        image = cv2.resize(image, (round(w*1200/max(w,h)), round(h*1200/max(w,h))))
    keypoints, descriptors = cv2.ORB_create(nfeatures=1600).detectAndCompute(image, None)
    if descriptors is None or len(keypoints) < 30:
        raise ValueError('Choose a clear landmark image with visible building or sign details.')
    scale = min(1,400/image.shape[1])
    thumbnail = cv2.resize(image, (round(image.shape[1]*scale),round(image.shape[0]*scale)))
    _, preview = cv2.imencode('.jpg', thumbnail, [cv2.IMWRITE_JPEG_QUALITY,70])
    return {'points': [list(k.pt) for k in keypoints], 'descriptors': base64.b64encode(descriptors.tobytes()).decode(), 'rows': len(keypoints), 'width': image.shape[1], 'height': image.shape[0], 'previewBase64':base64.b64encode(preview).decode()}


def recognize_landmark(data):
    query = landmark_features(data['imageBase64'])
    qdesc = np.frombuffer(base64.b64decode(query['descriptors']), np.uint8).reshape((-1,32))
    matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
    candidates = []
    for reference in data.get('references', [])[:100]:
        features = reference['features']
        desc = np.frombuffer(base64.b64decode(features['descriptors']), np.uint8).reshape((-1,32))
        pairs = matcher.knnMatch(desc, qdesc, k=2)
        good = [pair[0] for pair in pairs if len(pair)==2 and pair[0].distance < .72*pair[1].distance]
        if len(good) < 12:
            continue
        src = np.float32([features['points'][m.queryIdx] for m in good]).reshape(-1,1,2)
        dst = np.float32([query['points'][m.trainIdx] for m in good]).reshape(-1,1,2)
        homography, mask = cv2.findHomography(src,dst,cv2.RANSAC,4.0)
        if homography is None or mask is None:
            continue
        inliers = int(mask.sum())
        selected = dst[mask.ravel()==1].reshape(-1,2)
        area = cv2.contourArea(cv2.convexHull(selected)) / (query['width']*query['height']) if len(selected)>2 else 0
        if inliers>=12 and inliers/len(good)>=.55 and area>.03:
            candidates.append({'id':reference['id'],'placeId':reference['placeId'],'inliers':inliers,'score':round(inliers/len(good),4)})
    candidates.sort(key=lambda c:c['inliers'],reverse=True)
    if not candidates or len(candidates)>1 and candidates[0]['inliers']<candidates[1]['inliers']*1.25:
        return {'matched':False}
    return {'matched':True,**candidates[0],'method':'ORB with RANSAC geometric verification'}
