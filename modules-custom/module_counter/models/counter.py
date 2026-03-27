from odoo import models, fields

class ButtonCounter(models.Model):
    _name = 'button.counter'
    _description = 'Button Counter'

    name = fields.Char(default="Compteur")
    counter = fields.Integer(default=0)

    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('done', 'Terminé')
    ], default='draft')

    def action_increment(self):
        for record in self:
            if record.state == 'draft':
                record.counter += 1

    def action_done(self):
        for record in self:
            record.state = 'done'