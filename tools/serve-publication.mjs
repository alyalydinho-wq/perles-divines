import {createPublicationServer} from '../services/publisher/public-server.mjs';
createPublicationServer('content/development/public').listen(4175,'127.0.0.1',()=>console.log('Publications de test locales : http://127.0.0.1:4175/latest.json. Aucun accès public Internet.'));
