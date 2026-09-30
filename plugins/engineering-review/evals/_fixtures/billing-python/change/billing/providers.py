from abc import ABC, abstractmethod

import stripe


class AbstractPaymentProvider(ABC):
    @abstractmethod
    def charge(self, amount_cents, customer_id):
        ...


class StripeProvider(AbstractPaymentProvider):
    def charge(self, amount_cents, customer_id):
        return stripe.PaymentIntent.create(amount=amount_cents, currency="eur", customer=customer_id, confirm=True)


class ProviderRegistry:
    _providers = {}

    @classmethod
    def register(cls, name, provider_class):
        cls._providers[name] = provider_class

    @classmethod
    def get(cls, name):
        return cls._providers[name]


class PaymentProviderFactory:
    @staticmethod
    def create(name="stripe"):
        return ProviderRegistry.get(name)()


ProviderRegistry.register("stripe", StripeProvider)
