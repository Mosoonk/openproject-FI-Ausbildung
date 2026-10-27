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

import { ApiV3ListFilter } from 'core-app/core/apiv3/paths/apiv3-list-resource.interface';

export interface INotificationPageQueryParameters {
  filter?:string|null;
  name?:string|null;
  customFilters?:ApiV3ListFilter[];
}

export function parseNotificationPageFilters(search:string):INotificationPageQueryParameters {
  const params = new URLSearchParams(search);
  const selectedValues = new Map<string, Set<string>>();

  params.forEach((value, key) => {
    const field = /^filters\[(actor_cf_\d+)\](?:\[\])?$/.exec(key)?.[1];
    if (!field || !value.trim()) return;

    if (!selectedValues.has(field)) selectedValues.set(field, new Set());
    selectedValues.get(field)!.add(value);
  });

  const customFilters:ApiV3ListFilter[] = Array.from(selectedValues, ([field, values]) => [
    field,
    '=',
    Array.from(values),
  ]);

  return {
    filter: params.get('filter'),
    name: params.get('name'),
    customFilters,
  };
}

export function buildNotificationApiFilters(
  facetFilters:ApiV3ListFilter[],
  filters:INotificationPageQueryParameters,
):ApiV3ListFilter[] {
  const legacyFilter:ApiV3ListFilter[] = filters.filter && filters.name
    ? [[filters.filter, '=', [filters.name]]]
    : [];

  return [
    ...facetFilters,
    ...legacyFilter,
    ...(filters.customFilters ?? []),
  ];
}
