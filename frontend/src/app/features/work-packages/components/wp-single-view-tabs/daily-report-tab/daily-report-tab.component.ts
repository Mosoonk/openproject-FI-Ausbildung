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
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  ElementRef,
  inject,
  Input,
  OnInit,
  ViewChild,
} from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { ToastService } from 'core-app/shared/components/toaster/toast.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';

interface DailyReportEntry {
  id:number;
  entry_date:string;
  entry_kind:string;
  status_type:string|null;
  yesterday_text:string;
  today_text:string;
  issue_text:string|null;
  risks_text:string|null;
  lock_version:number;
  can_correct:boolean;
  can_delete:boolean;
  correction_history:DailyReportCorrection[];
}

interface DailyReportCorrection {
  revision_number:number;
  comment:string;
  actor:{ id:number; name:string };
  created_at:string;
  changes:{ field:string; before:string|null; after:string|null }[];
}

@Component({
  selector: 'op-daily-report-tab',
  templateUrl: './daily-report-tab.component.html',
  styleUrls: ['./daily-report-tab.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class DailyReportTabComponent implements OnInit {
  private readonly http = inject(HttpClient);
  private readonly pathHelper = inject(PathHelperService);
  private readonly changeDetectorRef = inject(ChangeDetectorRef);
  private readonly toastService = inject(ToastService);
  private readonly I18n = inject(I18nService);

  @Input() public workPackage:WorkPackageResource;
  @ViewChild('createForm') private createForm?:ElementRef<HTMLFormElement>;

  public entries:DailyReportEntry[] = [];
  public loadFailed = false;
  public requestError?:string;
  public validationFailed = false;
  public fieldErrors:Record<string, string> = {};
  public editingEntryId?:number;
  public entryKind = 'report';
  @Input() public readOnly = window.location.pathname.includes('/notifications/details/');
  private readonly collapsedEntryIds = new Set<number>();
  private readonly visibleHistoryEntryIds = new Set<number>();
  public readonly todayDate = this.dateInputValue(new Date());
  public readonly earliestParticipantDate = this.dateInputValue(
    new Date(new Date().setDate(new Date().getDate() - 7)),
  );

  public ngOnInit():void {
    this.loadEntries();
  }

  public createEntry(entryDate:string, entryKind:string, statusType:string, yesterdayText:string, todayText:string, issueText:string, risksText:string):void {
    this.requestError = undefined;
    this.validationFailed = false;
    this.fieldErrors = {};
    this.http.post<DailyReportEntry>(this.entriesUrl(), {
      daily_report_entry: {
        entry_date: entryDate || this.todayDate,
        entry_kind: entryKind,
        status_type: statusType,
        yesterday_text: entryKind === 'report' ? yesterdayText : null,
        today_text: entryKind === 'report' ? todayText : null,
        issue_text: entryKind === 'report' ? issueText || null : null,
        risks_text: entryKind === 'report' ? risksText || null : null,
      },
    }).subscribe({
      next: () => {
        this.createForm?.nativeElement.reset();
        this.entryKind = 'report';
        this.requestError = undefined;
        this.validationFailed = false;
        this.fieldErrors = {};
        this.toastService.addSuccess(this.I18n.t('js.notice_successful_create'));
        this.loadEntries();
      },
      error: (error:HttpErrorResponse) => {
        this.applyRequestError(error);
        this.changeDetectorRef.markForCheck();
      },
    });
  }

  public onEntryKindChange(entryKind:string, statusSelect:HTMLSelectElement):void {
    this.entryKind = entryKind;
    if (entryKind === 'report') statusSelect.value = 'betrieb';
  }

  public onStatusTypeChange(statusType:string, entryKindSelect:HTMLSelectElement):void {
    this.clearFieldError('status_type');
    this.entryKind = statusType === 'betrieb' ? 'report' : 'status';
    entryKindSelect.value = this.entryKind;
  }

  public updateEntry(entry:DailyReportEntry, comment:string, yesterdayText:string, todayText:string, issueText:string, risksText:string):void {
    this.requestError = undefined;
    this.fieldErrors = {};
    this.http.patch<DailyReportEntry>(`${this.entriesUrl()}/${entry.id}`, {
      daily_report_entry: {
        lock_version: entry.lock_version,
        comment,
        yesterday_text: yesterdayText,
        today_text: todayText,
        issue_text: issueText || null,
        risks_text: risksText || null,
      },
    }).subscribe({
      next: () => {
        this.editingEntryId = undefined;
        this.loadEntries();
      },
      error: (error:HttpErrorResponse) => {
        this.applyRequestError(error);
        this.changeDetectorRef.markForCheck();
      },
    });
  }

  public startEditing(entryId:number):void {
    this.fieldErrors = {};
    this.requestError = undefined;
    this.editingEntryId = entryId;
  }

  public cancelEditing():void {
    this.editingEntryId = undefined;
    this.fieldErrors = {};
    this.requestError = undefined;
  }

  public deleteEntry(entry:DailyReportEntry, comment:string):void {
    this.requestError = undefined;
    this.http.delete(`${this.entriesUrl()}/${entry.id}`, { body: { lock_version: entry.lock_version, comment } }).subscribe({
      next: () => {
        this.loadEntries();
      },
      error: (error:HttpErrorResponse) => {
        this.applyRequestError(error);
        this.changeDetectorRef.markForCheck();
      },
    });
  }

  public toggleEntry(entryId:number):void {
    if (this.collapsedEntryIds.has(entryId)) {
      this.collapsedEntryIds.delete(entryId);
    } else {
      this.collapsedEntryIds.add(entryId);
    }
  }

  public entryCollapsed(entryId:number):boolean {
    return this.collapsedEntryIds.has(entryId);
  }

  public markInvalid(field:string):void {
    this.validationFailed = true;
    this.fieldErrors = { ...this.fieldErrors, [field]: 'Dieses Feld ist erforderlich.' };
    this.requestError = 'Bitte überprüfen Sie die markierten Felder.';
    this.changeDetectorRef.markForCheck();
  }

  public clearFieldError(field:string):void {
    if (!this.fieldErrors[field]) return;

    const remainingErrors = { ...this.fieldErrors };
    delete remainingErrors[field];
    this.fieldErrors = remainingErrors;
  }

  public fieldError(field:string):string|undefined {
    return this.fieldErrors[field];
  }

  public toggleHistory(entryId:number, event:Event):void {
    event.stopPropagation();
    if (this.visibleHistoryEntryIds.has(entryId)) {
      this.visibleHistoryEntryIds.delete(entryId);
    } else {
      this.visibleHistoryEntryIds.add(entryId);
    }
  }

  public historyVisible(entryId:number):boolean {
    return this.visibleHistoryEntryIds.has(entryId);
  }

  public correctionFieldLabel(field:string):string {
    return {
      yesterday_text: 'Was habe ich gestern gemacht?',
      today_text: 'Was werde ich heute machen?',
      issue_text: 'Probleme',
      risks_text: 'Risiken',
    }[field] ?? field;
  }

  public correctionDate(value:string):string {
    return new Intl.DateTimeFormat('de-DE', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
  }

  public entryTitle(entry:DailyReportEntry):string {
    const [year, month, day] = entry.entry_date.split('-');
    const date = year && month && day ? `${day}.${month}.${year}` : entry.entry_date;
    const kind = entry.entry_kind === 'status' ? 'Status' : 'Bericht';
    const status = this.statusLabel(entry.status_type) || (entry.entry_kind === 'report' ? 'Betrieb' : '—');
    return `${date} | ${kind} | ${status}`;
  }

  public statusLabel(status:string|null):string {
    const labels:Record<string, string> = {
      berufsschule: 'Berufsschule',
      praktikum: 'Praktikum',
      krank: 'Krank',
      betrieb: 'Betrieb',
    };

    return status ? labels[status] || status : '';
  }

  private loadEntries():void {
    this.http.get<DailyReportEntry[]>(this.entriesUrl()).subscribe({
      next: (entries) => {
        this.entries = entries;
        this.collapsedEntryIds.clear();
        entries.forEach((entry) => this.collapsedEntryIds.add(entry.id));
        this.loadFailed = false;
        this.changeDetectorRef.markForCheck();
      },
      error: () => {
        this.loadFailed = true;
        this.changeDetectorRef.markForCheck();
      },
    });
  }

  private entriesUrl():string {
    return `${this.pathHelper.staticBase}/work_packages/${this.workPackage.id}/daily_report_entries`;
  }

  private applyRequestError(error:HttpErrorResponse):void {
    const response:unknown = error.error;
    if (this.hasValidationErrors(response)) {
      const fieldErrors:Record<string, string> = {};
      Object.entries(response.errors).forEach(([field, value]) => {
        const fieldMessages:unknown[] = Array.isArray(value) ? value as unknown[] : [value];
        const messagesForField = fieldMessages.filter((message):message is string => typeof message === 'string');
        if (messagesForField.length > 0) fieldErrors[field] = messagesForField.join(' ');
      });
      if (Object.keys(fieldErrors).length > 0) {
        this.validationFailed = true;
        this.fieldErrors = fieldErrors;
        this.requestError = 'Bitte überprüfen Sie die markierten Felder.';
        this.changeDetectorRef.markForCheck();
        return;
      }
    }

    this.requestError = 'Die Änderung konnte nicht gespeichert werden. Bitte überprüfen Sie die Eingabe.';
    this.changeDetectorRef.markForCheck();
  }

  private hasValidationErrors(value:unknown):value is { errors:Record<string, unknown> } {
    if (typeof value !== 'object' || value === null || !('errors' in value)) return false;
    return typeof value.errors === 'object' && value.errors !== null;
  }

  private dateInputValue(date:Date):string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
