const express = require('express');
const _ = require('lodash');
const { JWTVerification, validation } = require('../../middleware');

module.exports = context => {
  const router = express.Router()

  // Create contract
  router.post('/', JWTVerification(context), validation('createContract'), async (req, res, next) => {
    try {
      const { publicAddress: user } = req.user;
      const contract = await context.db.Contract.create({ user, ...req.body });

      res.json({ success: true, contract });
    } catch (e) {
      next(e);
    }
  });

  // Get list of contracts for specific user
  router.get('/', JWTVerification(context), async (req, res, next) => {
    try {
      const { publicAddress: user } = req.user;
      const contracts = await context.db.Contract.find({ user }, { _id: 1, contractAddress: 1, title: 1 });

      res.json({ success: true, contracts });
    } catch (e) {
      next(e);
    }
  });

  // Get list of contracts with all products and offers
  router.get('/full', validation('filterAndSort', 'query'), async (req, res, next) => {
    try {
      const { pageNum = '1', itemsPerPage = '20', sortBy = 'name', sort = '1', blockchain = '', category = '' } = req.query;
      const pageSize = parseInt(itemsPerPage, 10);
      const sortDirection = parseInt(sort, 10);
      const skip = (parseInt(pageNum, 10) - 1) * pageSize;

      const lookupProduct = {
        $lookup: {
          from: 'Product',
          let: {
            contr: '$contractAddress'
          },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    {
                      $eq: [
                        '$contract',
                        '$$contr'
                      ]
                    }
                  ]
                }
              }
            }
          ],
          as: 'products'
        }
      };

      const foundCategory = await context.db.Category.findOne({ name: category });

      if (foundCategory) {
        _.set(lookupProduct, '$lookup.let.categoryF', foundCategory._id);
        _.set(lookupProduct, '$lookup.pipeline[0].$match.$expr.$and[1]', { $eq: ['$category', '$$categoryF'] });
      }

      const options = [
        lookupProduct,
        { $unwind: '$products' },
        {
          $lookup: {
            from: 'OfferPool',
            let: {
              contr: '$contractAddress',
              prod: '$products.collectionIndexInContract'
            },
            pipeline: [
              {
                $match: {
                  $expr: {
                    $and: [
                      {
                        $eq: [
                          '$contract',
                          '$$contr'
                        ]
                      },
                      {
                        $eq: [
                          '$product',
                          '$$prod'
                        ]
                      }
                    ]
                  }
                }
              }
            ],
            as: 'offerPool'
          }
        },
        { $unwind: '$offerPool' },
        {
          $lookup: {
            from: 'Offer',
            let: {
              offerPoolL: '$offerPool.marketplaceCatalogIndex',
              contractL: '$contractAddress'
            },
            pipeline: [
              {
                $match: {
                  $expr: {
                    $and: [
                      {
                        $eq: [
                          '$contract',
                          '$$contractL'
                        ]
                      },
                      {
                        $eq: [
                          '$offerPool',
                          '$$offerPoolL'
                        ]
                      }
                    ]
                  }
                }
              }
            ],
            as: 'products.offers'
          }
        }
      ];

      const foundBlockchain = await context.db.Blockchain.findOne({ name: blockchain });

      if (foundBlockchain) {
        options.unshift({ $match: { blockchain: foundBlockchain.hash } });
      }

      const contracts = await context.db.Contract.aggregate(options)
        .sort({ [`products.${sortBy}`]: sortDirection })
        .skip(skip)
        .limit(pageSize);

      res.json({ success: true, contracts });
    } catch (e) {
      next(e);
    }
  });

  router.use('/:contractAddress', JWTVerification(context), validation('singleContract', 'params'), (req, res, next) => {
    req.contractAddress = req.params.contractAddress.toLowerCase();
    next();
  }, require('./contract')(context));

  return router
}
