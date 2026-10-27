//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  buildNotificationApiFilters,
  parseNotificationPageFilters,
} from './notification-filters';

describe('notification custom filters', () => {
  it('converts multiple values of different user attributes into API filters', () => {
    const filters = parseNotificationPageFilters(
      '?filters%5Bactor_cf_1%5D%5B%5D=LJ_1&filters%5Bactor_cf_1%5D%5B%5D=LJ_2'
      + '&filters%5Bactor_cf_2%5D%5B%5D=Vollzeit&filters%5Bactor_cf_3%5D%5B%5D=IT',
    );

    expect(buildNotificationApiFilters([['readIAN', '=', false]], filters)).toEqual([
      ['readIAN', '=', false],
      ['actor_cf_1', '=', ['LJ_1', 'LJ_2']],
      ['actor_cf_2', '=', ['Vollzeit']],
      ['actor_cf_3', '=', ['IT']],
    ]);
  });

  it('keeps standard reason filters alongside user attributes', () => {
    const filters = parseNotificationPageFilters(
      '?filter=reason&name=mentioned&filters%5Bactor_cf_1%5D%5B%5D=LJ_1',
    );

    expect(buildNotificationApiFilters([], filters)).toEqual([
      ['reason', '=', ['mentioned']],
      ['actor_cf_1', '=', ['LJ_1']],
    ]);
  });

  it('ignores unrelated or empty query parameters', () => {
    const filters = parseNotificationPageFilters(
      '?filters%5Bother%5D%5B%5D=ignored&filters%5Bactor_cf_1%5D%5B%5D=',
    );

    expect(buildNotificationApiFilters([], filters)).toEqual([]);
  });
});
