import unittest
import worker
import park_intelligence as intelligence


class ParkIntelligenceChecks(unittest.TestCase):
    def test_anomaly_model_requires_activity_samples_and_returns_review_reasons(self):
        samples=[{'uid':str(i),'reservations':i%5+1,'orders':1,'spendMinor':2500,'sessions':1} for i in range(30)]
        samples.append({'uid':'outlier','reservations':200,'cancellations':190,'missed':20,'orders':50,'spendMinor':500000,'sessions':15})
        result=intelligence.anomalies({'samples':samples})
        self.assertIn('Isolation Forest',result['method'])
        self.assertIn('outlier',[f['uid'] for f in result['flags']])
        self.assertNotIn('Isolation Forest',intelligence.anomalies({'samples':samples[:3]})['method'])
    def test_recommendations_fit_real_catalogue_and_respect_height_and_closures(self):
        places = [{'id': 'thrill', 'name': 'Dragon coaster', 'category': 'Thrill rides', 'description': 'High speed coaster', 'status': 'open', 'minHeightCm': 140}, {'id': 'family', 'name': 'Family river', 'category': 'Family rides', 'status': 'open', 'minHeightCm': 0}, {'id': 'closed', 'name': 'Closed family ride', 'category': 'Family rides', 'status': 'closed'}]
        data = {'places': places, 'interests': ['Family rides'], 'foodPreferences': [], 'heightCm': 120}
        result = intelligence.recommendations(data)['recommendations']
        self.assertEqual([r['id'] for r in result], ['family'])
        data['heightCm'] = 170
        data['ratings'] = [{'attractionId': 'family', 'rating': 5}]
        self.assertEqual(intelligence.recommendations(data)['recommendations'][0]['id'], 'family')

    def test_kde_uses_queue_weights_and_has_no_invented_people(self):
        empty = intelligence.queue_density({'points': []})
        self.assertTrue(all(v == 0 for v in empty['values']))
        result = intelligence.queue_density({'points': [{'x': .2, 'y': .2, 'weight': 100}, {'x': .8, 'y': .8, 'weight': 1}]})
        self.assertEqual(result['queuePlaces'], 101)
        self.assertGreater(result['values'][6*32+6], result['values'][25*32+25])

    def test_multilingual_retrieval_and_current_catalogue_answers(self):
        for lang, question in [('en','How to buy tickets?'),('ms','Bagaimana beli tiket?'),('zh','如何买门票')]:
            self.assertEqual(intelligence.assistant({'language':lang,'message':question})['actions'],['tickets'])
        result = intelligence.assistant({'language':'en','message':'Where is Sapphire Rapids?','places':[{'name':'Sapphire Rapids','id':'rapids','status':'maintenance','minHeightCm':120}]})
        self.assertEqual(result['placeId'],'rapids')
        self.assertIn('Maintenance',result['answer'])

    def test_landmark_requires_geometric_matches_and_rejects_other_images(self):
        rng = worker.np.random.default_rng(42)
        source = rng.integers(0,255,(600,700,3),dtype=worker.np.uint8)
        worker.cv2.putText(source,'PARK LANDMARK',(40,300),worker.cv2.FONT_HERSHEY_SIMPLEX,2,(255,255,255),4)
        encoded = worker.jpeg(source)
        features = intelligence.landmark_features(encoded)
        matrix = worker.np.float32([[1,0,10],[0,1,15]])
        shifted = worker.cv2.warpAffine(source,matrix,(700,600))
        references = [{'id':'fixture-sign','placeId':'fixture-place','features':features}]
        result = intelligence.recognize_landmark({'imageBase64':worker.jpeg(shifted),'references':references})
        self.assertTrue(result['matched'])
        other = rng.integers(0,255,(600,700,3),dtype=worker.np.uint8)
        self.assertFalse(intelligence.recognize_landmark({'imageBase64':worker.jpeg(other),'references':references})['matched'])


if __name__ == '__main__':
    unittest.main()
